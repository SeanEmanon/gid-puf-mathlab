%% Script for analyzing the stability of PUF responses
clear; close all; clc;

%% ------------------------------------------------------------------------
% 1. Data request
% ------------------------------------------------------------------------
fprintf('=== Analysis of PUF response stability ===\n');
Ttarget = input('Enter HDintra threshold (default 0.1): ');
if isempty(Ttarget); Ttarget = 0.1; end

hw_range = input('Enter the Hamming weight range [a,b] (default [0.4,0.6]): ');
if isempty(hw_range); hw_range = [0.4, 0.6]; end

root_dir = uigetdir(pwd, 'Select the root folder containing the devices');
if root_dir == 0; error('No folder selected.'); end
fprintf('Root folder: %s\n', root_dir);

%% ------------------------------------------------------------------------
% 2. Function for reading a single dump file
% ------------------------------------------------------------------------
function [addrs, vals] = read_dump_file(filepath)
    fid = fopen(filepath, 'r');
    addrs = []; vals = {};
    if fid == -1; return; end
    while ~feof(fid)
        line = strtrim(fgetl(fid));
        if isempty(line) || line(1) == '#'; continue; end
        parts = strsplit(line, {' ', '\t'});
        parts = parts(~cellfun(@isempty, parts));
        if length(parts) < 3; continue; end
        addr_str = parts{2};
        if startsWith(addr_str, '0x') || startsWith(addr_str, '0X')
            addr_str = addr_str(3:end);
        end
        if ~all(isstrprop(addr_str, 'xdigit')); continue; end
        addrs = [addrs; hex2dec(addr_str)];
        vals{end+1} = parts{3};
    end
    fclose(fid);
    % Remove potential duplicate addresses (keeping the first occurrences)
    [addrs, ia] = unique(addrs, 'stable');
    vals = vals(ia);
end

%% ------------------------------------------------------------------------
% 3. Function for converting a hex string into a bit vector
% ------------------------------------------------------------------------
function bits = hex_to_bits(hex_str, bit_len)
    % hex_str: line, bit_len: number of bits (must be a multiple of 4)
    n_bytes = bit_len / 4;
    if length(hex_str) ~= n_bytes
        error('The length of the hex string does not match bit_len');
    end
    num = hex2dec(hex_str);
    bits = zeros(1, bit_len);
    for i = 1:bit_len
        bits(i) = bitget(num, bit_len - i + 1);
    end
end

%% ------------------------------------------------------------------------
% 4. Defining the list of devices
% ------------------------------------------------------------------------
items = dir(root_dir);
is_sub = [items.isdir] & ~ismember({items.name}, {'.','..'});
device_names = {items(is_sub).name};
fprintf('Devices found: %d\n', length(device_names));
if isempty(device_names); error('No subfolders with devices.'); end

% Creating a folder for the results
out_dir = fullfile(root_dir, 'puf_analysis_results');
if ~exist(out_dir, 'dir'); mkdir(out_dir); end

%% ------------------------------------------------------------------------
% 5. Basic cycle on devices
% ------------------------------------------------------------------------
for dev_idx = 1:length(device_names)
    dev_name = device_names{dev_idx};
    dev_path = fullfile(root_dir, dev_name);
    fprintf('\n========================================\n');
    fprintf('Device %d/%d: %s\n', dev_idx, length(device_names), dev_name);
    
    % --- 5.1 Searching for dump files ---
    dump_files = dir(fullfile(dev_path, '*.txt'));
    if length(dump_files) < 2
        fprintf('  Insufficient dumps (<2), skipping \n');
        continue;
    end
    n_dumps = length(dump_files);
    fprintf('  Dumps found: %d\n', n_dumps);
    
    % --- 5.2 Determining word length (in bits) based on the first value from the first dump ---
    first_file = fullfile(dev_path, dump_files(1).name);
    [~, val_cell] = read_dump_file(first_file);
    if isempty(val_cell)
        fprintf('  Failed to read the first dump, skipping.\n');
        continue;
    end
    bit_len = length(val_cell{1}) * 4;
    fprintf('  Word length: %d byte\n', bit_len);
    
    % --- 5.3 Data collection by address ---
    % Using a dictionary: address -> matrix [n_dumps x bit_len]
    addr_data = containers.Map('KeyType', 'uint64', 'ValueType', 'any');
    all_addrs = [];  % all encountered addresses
    
    for d = 1:n_dumps
        filepath = fullfile(dev_path, dump_files(d).name);
        fprintf('    Reading %s (%d/%d)\n', dump_files(d).name, d, n_dumps);
        [addrs, vals] = read_dump_file(filepath);
        for i = 1:length(addrs)
            a = addrs(i);
            hex_str = vals{i};
            % Checking whether the length of a hex string matches the word length
            if length(hex_str) ~= bit_len/4
                fprintf('      Warning: address 0x%X has an incorrect length (%d instead of %d); skipping.\n', ...
                    a, length(hex_str)*4, bit_len);
                continue;
            end
            bits = hex_to_bits(hex_str, bit_len);
            if ~addr_data.isKey(a)
                % Initialize a matrix for this address
                addr_data(a) = NaN(n_dumps, bit_len);
                all_addrs = [all_addrs; a];
            end
            cur = addr_data(a);
            cur(d, :) = bits;
            addr_data(a) = cur;
        end
    end
    
    all_addrs = unique(all_addrs);
    fprintf('  Total unique addresses: %d\n', length(all_addrs));
    
    % --- 5.4 Selection of addresses present in all dumps ---
    complete_addrs = [];
    for a = all_addrs'
        mat = addr_data(a);
        if ~any(isnan(mat(:)))   % no missed dumps
            complete_addrs = [complete_addrs; a];
        end
    end
    fprintf('  Addresses present in all dumps: %d\n', length(complete_addrs));
    if isempty(complete_addrs)
        fprintf('  No full addresses; skipping the device.\n');
        continue;
    end
    
    % --- 5.5 Calculation of HDintra for each full address ---
    N = n_dumps;
    n_pairs = N*(N-1)/2;
    hd_intra = zeros(length(complete_addrs), 1);
    
    for idx = 1:length(complete_addrs)
        a = complete_addrs(idx);
        bits_mat = addr_data(a);   % matrix [N x bit_len]
        total_dist = 0;
        % Pairwise comparison of all rows
        for i = 1:N-1
            for j = i+1:N
                % Hamming distance between strings i and j
                dist = sum(bits_mat(i,:) ~= bits_mat(j,:));
                total_dist = total_dist + dist;
            end
        end
        hd_intra(idx) = total_dist / (bit_len * n_pairs);
    end
    
    % --- 5.6 First stage of filtering: stable addresses ---
    stable_mask = (hd_intra <= Ttarget);
    stable_addrs = complete_addrs(stable_mask);
    stable_hd = hd_intra(stable_mask);
    fprintf('  Stable addresses (HDintra <= %.3f): %d\n', Ttarget, length(stable_addrs));
    if isempty(stable_addrs)
        fprintf('  No stable addresses; skipping device.\n');
        continue;
    end
    
    % --- 5.7 Calculating the modal value for each stable address ---
    stable_modes = zeros(length(stable_addrs), 1);
    for idx = 1:length(stable_addrs)
        a = stable_addrs(idx);
        bits_mat = addr_data(a);
        % Let's convert each string of bits into a number
        words = zeros(N, 1);
        for i = 1:N
            bits = bits_mat(i, :);
            w = 0;
            for b = 1:bit_len
                w = bitor(bitshift(w, 1), bits(b));
            end
            words(i) = w;
        end
        stable_modes(idx) = mode(words);
    end
    
    % --- 5.8 Second filtering stage: based on normalized Hamming weight ---
    a_low = hw_range(1); a_high = hw_range(2);
    hw_norm_vals = zeros(length(stable_modes), 1);
    final_mask = false(length(stable_modes), 1);
    for idx = 1:length(stable_modes)
        val = stable_modes(idx);
        % Calculating the normalized Hamming weight
        bits = zeros(1, bit_len);
        for b = 1:bit_len
            bits(b) = bitget(val, bit_len - b + 1);
        end
        hw = sum(bits) / bit_len;
        hw_norm_vals(idx) = hw;
        if hw >= a_low && hw <= a_high
            final_mask(idx) = true;
        end
    end
    
    final_addrs = stable_addrs(final_mask);
    final_modes = stable_modes(final_mask);
    fprintf('  After filtering by Hamming weight [%.2f,%.2f]: %d\n', a_low, a_high, length(final_addrs));
    
    % --- 5.9 Saving the result ---
    out_filename = sprintf('%s_puf_analysis_HDintra_HW.txt', dev_name);
    out_path = fullfile(out_dir, out_filename);
    fid = fopen(out_path, 'w');
    fprintf(fid, '# PUF Stability Analysis Report\n');
    fprintf(fid, '# Device: %s\n', dev_name);
    fprintf(fid, '# Number of dumps: %d\n', N);
    fprintf(fid, '# Word length: %d bits\n', bit_len);
    fprintf(fid, '# HDintra threshold: %.4f\n', Ttarget);
    fprintf(fid, '# Hamming weight range: [%.4f, %.4f]\n', a_low, a_high);
    fprintf(fid, '# Total unique addresses: %d\n', length(all_addrs));
    fprintf(fid, '# Addresses in all dumps: %d\n', length(complete_addrs));
    fprintf(fid, '# Stable addresses (after HDintra): %d\n', length(stable_addrs));
    fprintf(fid, '# Final addresses (after HW filter): %d\n', length(final_addrs));
    fprintf(fid, '#------------------------------------------------\n');
    fprintf(fid, '# Index\tAddress(hex)\tValue(hex)\n');
    for i = 1:length(final_addrs)
        
        hex_val = dec2hex(final_modes(i), bit_len/4);
        fprintf(fid, '%d\t0x%X\t%s\n', i, final_addrs(i), hex_val);
    end
    fclose(fid);
    fprintf('  Results saved: %s\n', out_path);
end

fprintf('\n=== Processing complete ===\n');