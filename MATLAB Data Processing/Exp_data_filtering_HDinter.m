%% Third-stage filtering script: Inter-Device Uniqueness (HDinter)
% Input: A folder containing results from the HDintra and HW filtering stages (one file per device)
% Output: A folder containing the filtered files (maintaining the original format)
%
% Filtering logic:
% - For each unique address encountered across the device files,
%   identify the subset of devices (Nk) where this address is present.
% - If Nk >= 2: calculate the mean HDinter value across all pairs.
%   If the mean falls within the range [a, b], retain the address on all Nk devices.
%   If it falls outside this range, retain the address on only one device
%   (selected randomly using a deterministic seed equal to the address value).
% - If Nk == 1: retain the address without further verification.
% - Addresses that do not appear in any file are ignored.

clear; close all; clc;

%% ------------------------------------------------------------------------
% 1. Parameter request
% ------------------------------------------------------------------------
fprintf('=== HDinter (cross-device uniqueness) ===\n');

% Folder with input data (HDintra + HW)
input_dir = uigetdir(pwd, 'Select the folder containing the filtered data (after HDintra+HW)');
if input_dir == 0
    error('No folder selected.');
end
fprintf('Inbox folder: %s\n', input_dir);

% Range for HDinter
hd_range = input('Enter range for HDinter [a,b] (default [0.4, 0.6]): ');
if isempty(hd_range)
    hd_range = [0.4, 0.6];
elseif length(hd_range) ~= 2
    error('The range must contain two numbers: [lower_bound, upper_bound]');
end
fprintf('Range HDinter: [%.4f, %.4f]\n', hd_range(1), hd_range(2));

%% ------------------------------------------------------------------------
% 2. Searching for input files and identifying devices
% ------------------------------------------------------------------------
input_files = dir(fullfile(input_dir, '*_puf_analysis.txt'));
if isempty(input_files)
    error('No files of the type *_puf_analysis.txt were found in the specified folder.');
end

n_devices = length(input_files);
fprintf('\n Devices found: %d\n', n_devices);

% Extracting device names from file names
device_names = cell(n_devices, 1);
for i = 1:n_devices
    % File name: "XXX_puf_analysis.txt" -> "XXX"
    [~, name] = fileparts(input_files(i).name);
    device_names{i} = strrep(name, '_puf_analysis', '');
end

%% ------------------------------------------------------------------------
% 3. Device file reading function (format after the 2nd stage)
% ------------------------------------------------------------------------
function [addr_hex, value_hex] = read_device_file(filepath)
    % Returns:
    %   addr_hex - cell array of strings containing hex addresses (without '0x')
    %   value_hex - cell array of strings containing hex values
    fid = fopen(filepath, 'r');
    if fid == -1
        addr_hex = {};
        value_hex = {};
        return;
    end
    
    addr_hex = {};
    value_hex = {};
    in_table = false;
    
    while ~feof(fid)
        line = strtrim(fgetl(fid));
        if isempty(line)
            continue;
        end
        
        % Defining the start of the table
        if contains(line, '#------------------------------------------------')
            in_table = true;
            continue;
        end
        
        % Skip lines with comments (starting with '#')
        if startsWith(line, '#')
            continue;
        end
        
        % Parsing table rows
        if in_table
            % Format: "Index\tAddress(hex)\tValue(hex)"
            parts = strsplit(line, {'\t', ' '});
            parts = parts(~cellfun(@isempty, parts));
            if length(parts) >= 3
                addr_str = parts{2};
                % Remove the '0x' prefix, if present
                if startsWith(addr_str, '0x') || startsWith(addr_str, '0X')
                    addr_str = addr_str(3:end);
                end
                addr_hex{end+1} = lower(addr_str);
                value_hex{end+1} = lower(parts{3});
            end
        end
    end
    
    fclose(fid);
end

%% ------------------------------------------------------------------------
% 4. Function for retrieving word length from a file (based on the header)
% ------------------------------------------------------------------------
function w = get_word_length(filepath)
    fid = fopen(filepath, 'r');
    w = 8; % default value
    if fid == -1
        return;
    end
    while ~feof(fid)
        line = fgetl(fid);
        if contains(line, 'Word length:')
            tokens = regexp(line, 'Word length:\s*(\d+)\s*bits', 'tokens');
            if ~isempty(tokens)
                w = str2double(tokens{1}{1});
                break;
            end
        end
        if contains(line, '#------------------------------------------------')
            break;
        end
    end
    fclose(fid);
end

%% ------------------------------------------------------------------------
% 5. Determining word length (taken from the first file)
% ------------------------------------------------------------------------
word_len = get_word_length(fullfile(input_dir, input_files(1).name));
fprintf('Word length: %d bit\n', word_len);

%% ------------------------------------------------------------------------
% 6. Reading data for all devices
% ------------------------------------------------------------------------
fprintf('\n Reading data from devices...\n');
% Structure: device_data{dev_idx} = containers.Map(addr_hex -> value_hex)
device_maps = cell(n_devices, 1);
all_addresses = {}; % all unique addresses (hex strings) across all devices

for i = 1:n_devices
    filepath = fullfile(input_dir, input_files(i).name);
    [addr_list, val_list] = read_device_file(filepath);
    
    % Create a Map for quick search
    dev_map = containers.Map('KeyType', 'char', 'ValueType', 'char');
    for j = 1:length(addr_list)
        addr = addr_list{j};
        val = val_list{j};
        dev_map(addr) = val;
        all_addresses{end+1} = addr;
    end
    device_maps{i} = dev_map;
    fprintf('  Device %d/%d: %s -> %d addr \n', i, n_devices, device_names{i}, dev_map.Count);
end

% Unique addresses
unique_addresses = unique(all_addresses);
n_unique = length(unique_addresses);
fprintf('\n Total unique addresses (across all devices): %d\n', n_unique);

%% ------------------------------------------------------------------------
% 7. Function hex string to bit vector
% ------------------------------------------------------------------------
function bits = hex_to_bits(hex_str, bit_len)
    % hex_str: string without '0x', bit_len: number of bits (must be a multiple of 4)
    n_bytes = bit_len / 4;
    if length(hex_str) ~= n_bytes
        error('The length of the hex string (%d) does not match bit_len (%d)', length(hex_str), n_bytes);
    end
    num = hex2dec(hex_str);
    bits = zeros(1, bit_len);
    for i = 1:bit_len
        bits(i) = bitget(num, bit_len - i + 1);
    end
end

%% ------------------------------------------------------------------------
% 8. Function for calculating the HDinter between two hex values
% ------------------------------------------------------------------------
function hd = hamming_distance_hex(hex1, hex2, bit_len)
    bits1 = hex_to_bits(hex1, bit_len);
    bits2 = hex_to_bits(hex2, bit_len);
    hd = sum(bits1 ~= bits2) / bit_len;
end

%% ------------------------------------------------------------------------
% 9. Function for randomly selecting one element with a deterministic seed
% ------------------------------------------------------------------------
function idx = deterministic_rand_choice(n, seed_val)
    % n: number of elements (1..n)
    % seed_val: a number (e.g., a hex address converted into a number)
    % Returns an index from 1 to n (deterministic, yet randomly distributed)
    if n == 1
        idx = 1;
        return;
    end
    rng(seed_val);
    idx = randi(n);
    % Reset the global seed to avoid affecting other calls
    rng('shuffle');
end

%% ------------------------------------------------------------------------
% 10. Main loop over unique addresses
% ------------------------------------------------------------------------
fprintf('\n=== Filtering by HDinter ===\n');

% For each device, we create a new Map (containing only the addresses that have passed the filter)
new_maps = cell(n_devices, 1);
for i = 1:n_devices
    new_maps{i} = containers.Map('KeyType', 'char', 'ValueType', 'char');
end

% Statistics
total_initial = 0;
total_final = 0;
addr_stats = struct();

for addr_idx = 1:n_unique
    addr = unique_addresses{addr_idx};
    
    % Determine which devices have this address
    present_devices = [];
    present_values = {};
    for dev_i = 1:n_devices
        if device_maps{dev_i}.isKey(addr)
            present_devices = [present_devices; dev_i];
            present_values{end+1} = device_maps{dev_i}(addr);
        end
    end
    
    Nk = length(present_devices);
    
    % Updating statistics
    for dev_i = present_devices'
        total_initial = total_initial + 1;
    end
    
    % Nk == 0 
    if Nk == 0
        continue;
    end
    
    % Nk == 1
    if Nk == 1
        dev_i = present_devices(1);
        new_maps{dev_i}(addr) = present_values{1};
        total_final = total_final + 1;
        continue;
    end
    
    % Nk >= 2
    num_pairs = Nk * (Nk - 1) / 2;
    sum_hd = 0;
    
    for p = 1:Nk-1
        for q = p+1:Nk
            val_p = present_values{p};
            val_q = present_values{q};
            hd_val = hamming_distance_hex(val_p, val_q, word_len);
            sum_hd = sum_hd + hd_val;
        end
    end
    
    mean_hd = sum_hd / num_pairs;
    
    % Range check
    if mean_hd >= hd_range(1) && mean_hd <= hd_range(2)
        
        for idx = 1:Nk
            dev_i = present_devices(idx);
            new_maps{dev_i}(addr) = present_values{idx};
            total_final = total_final + 1;
        end
    else
        
        seed_val = hex2dec(addr);
        keep_idx = deterministic_rand_choice(Nk, seed_val);
        dev_i = present_devices(keep_idx);
        new_maps{dev_i}(addr) = present_values{keep_idx};
        total_final = total_final + 1;
    end
    
    
    if mod(addr_idx, 1000) == 0
        fprintf('  Addresses processed: %d / %d\n', addr_idx, n_unique);
    end
end

fprintf('\n=== Filtration results ===\n');
fprintf('Total entries (address-device) at the input: %d\n', total_initial);
fprintf('Total number of records (address-device) at the output: %d\n', total_final);
fprintf('Compression ratio: %.2f%%\n', (1 - total_final/total_initial)*100);

%% ------------------------------------------------------------------------
% 11. Saving results to a new folder
% ------------------------------------------------------------------------
out_dir = fullfile(input_dir, 'puf_hdinter_filtered');
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end
fprintf('\nSaving results to: %s\n', out_dir);

for dev_i = 1:n_devices
    dev_name = device_names{dev_i};
    dev_map = new_maps{dev_i};
    
    % We obtain the addresses sorted 
    addr_list = keys(dev_map);
    if isempty(addr_list)
        fprintf('  Device %s: no addresses after filtering\n', dev_name);
        % We still save an empty file (with a header but no data)
        addr_numeric = [];
        sorted_addr_str = {};
        sorted_values = {};
    else
        addr_numeric = zeros(length(addr_list), 1);
        for j = 1:length(addr_list)
            addr_numeric(j) = hex2dec(addr_list{j});
        end
        [~, sort_idx] = sort(addr_numeric);
        sorted_addr_str = addr_list(sort_idx);
        sorted_values = cell(length(sorted_addr_str), 1);
        for j = 1:length(sorted_addr_str)
            sorted_values{j} = dev_map(sorted_addr_str{j});
        end
    end
    
    % Generating the output file
    out_filename = sprintf('%s_puf_hdinter_analysis.txt', dev_name);
    out_path = fullfile(out_dir, out_filename);
    
    fid = fopen(out_path, 'w');
    fprintf(fid, '# PUF HDinter Analysis Report\n');
    fprintf(fid, '# Device: %s\n', dev_name);
    fprintf(fid, '# Word length: %d bits\n', word_len);
    fprintf(fid, '# HDinter range: [%.4f, %.4f]\n', hd_range(1), hd_range(2));
    
    % Calculating the initial number of addresses for this device
    init_count = device_maps{dev_i}.Count;
    final_count = dev_map.Count;
    fprintf(fid, '# Total initial addresses: %d\n', init_count);
    fprintf(fid, '# Final addresses (after HDinter filter): %d\n', final_count);
    fprintf(fid, '#------------------------------------------------\n');
    fprintf(fid, '# Index\tAddress(hex)\tValue(hex)\n');
    
    for j = 1:length(sorted_addr_str)
        fprintf(fid, '%d\t0x%s\t%s\n', j, upper(sorted_addr_str{j}), upper(sorted_values{j}));
    end
    
    fclose(fid);
    fprintf('  Saved: %s (%d addresses)\n', out_filename, final_count);
end

fprintf('\n=== Processing complete ===\n');
fprintf('The results have been saved to the folder:\n%s\n', out_dir);