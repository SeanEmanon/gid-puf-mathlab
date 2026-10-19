%% Script for extracting PUF data for ALL devices (16-bit words, WITHOUT overlap)
clear; close all; clc;

%% 1. Request for a data file
[filename, pathname] = uigetfile({'*.csv', 'CSV files (*.csv)'}, 'Select a file containing PUF measurements');
if isequal(filename, 0)
    fprintf('No file selected. Program terminated.\n');
    return;
end
filename = fullfile(pathname, filename);
fprintf('File selected: %s\n', filename);

data = readtable(filename, 'PreserveVariableNames', true);

%% 2. Creating the main folder
output_dir = 'extracted_puf_data_all_16bit_no_overlap';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

%% 3.Obtain unique devices
unique_devices = unique(data.device_id);
fprintf('Devices found: %d\n', length(unique_devices));

%% 4. Processing of each device
total_files = 0;

for dev_idx = 1:length(unique_devices)
    target_device = unique_devices{dev_idx};
    fprintf('\n========================================\n');
    fprintf('Device processing %d/%d: %s\n', dev_idx, length(unique_devices), target_device);
    fprintf('========================================\n');
    
    % Filtering data for this device
    device_data = data(strcmp(data.device_id, target_device), :);
    fprintf('Measurements found: %d\n', height(device_data));
    
    % Creating a folder for the device
    safe_device_name = strrep(target_device, ':', '_');
    device_folder = fullfile(output_dir, safe_device_name);
    if ~exist(device_folder, 'dir')
        mkdir(device_folder);
    end
    
    % Process each dimension
    for i = 1:height(device_data)
        dump_idx = device_data.dump_index(i);
        start_addr = device_data.puf_addr(i);
        puf_len = device_data.puf_len(i);
        hex_str = device_data.puf_data_hex{i};
        
        % Extract the bytes (each byte = 2 symbols)
        num_bytes = floor(length(hex_str) / 2);
        
        % Number of 16-bit words WITHOUT overlap = floor(num_bytes / 2)
        num_words = floor(num_bytes / 2);
        
        % Pre-allocate arrays for the table
        indices = (1:num_words)';
        
        % The addresses are spaced by one (with a step of 2)
        addresses = start_addr + (0:2:(2*num_words-2))';
        
        word_values = cell(num_words, 1);
        
        % We form 16-bit words by combining pairs of consecutive bytes, WITHOUT overlap.
        for j = 1:num_words
            % Character indices in hex_str (MATLAB 1-based indexing)
            idx_high_start = (j-1)*4 + 1;
            idx_high_end   = (j-1)*4 + 2;
            idx_low_start  = (j-1)*4 + 3;
            idx_low_end    = (j-1)*4 + 4;
            
            byte_high = hex_str(idx_high_start:idx_high_end);
            byte_low  = hex_str(idx_low_start:idx_low_end);
            word_hex  = [byte_high, byte_low];  % 4 symbols
            word_values{j} = upper(word_hex);   
        end
        
        % Creating a table
        result_table = table(indices, addresses, word_values, ...
            'VariableNames', {'Index', 'Address', 'Value'});
        
        % Saving to a file
        output_filename = sprintf('%s_dump_%02d_16bit_no_overlap.txt', safe_device_name, dump_idx);
        output_path = fullfile(device_folder, output_filename);
        
        fid = fopen(output_path, 'w');
        fprintf(fid, '# PUF Data Extraction Report (16-bit words, NO overlapping)\n');
        fprintf(fid, '# Device ID: %s\n', target_device);
        fprintf(fid, '# Dump Index: %d\n', dump_idx);
        fprintf(fid, '# Start Address: 0x%X\n', start_addr);
        fprintf(fid, '# Total Bytes: %d\n', num_bytes);
        fprintf(fid, '# Expected Bytes (puf_len): %d\n', puf_len);
        fprintf(fid, '# Number of 16-bit words (no overlap): %d\n', num_words);
        fprintf(fid, '# Format: Index | Address (Hex) | Value (Hex, 16-bit)\n');
        fprintf(fid, '#------------------------------------------------\n');
        
        for j = 1:height(result_table)
            fprintf(fid, '%d\t0x%X\t%s\n', ...
                result_table.Index(j), ...
                result_table.Address(j), ...
                result_table.Value{j});
        end
        
        fclose(fid);
        
        % Integrity check
        expected_words = floor(puf_len / 2);
        if num_words ~= expected_words
            fprintf('  Warning: Dump %d - was expected %d words, obtained %d\n', ...
                dump_idx, expected_words, num_words);
        else
            fprintf('  Dump %d: OK (%d words, addresses: 0x%X, 0x%X, ...)\n', ...
                dump_idx, num_words, start_addr, start_addr+2);
        end
        
        total_files = total_files + 1;
    end
    
    fprintf('Device %s has been processed. Files created: %d\n', ...
        target_device, height(device_data));
end

fprintf('\n========================================\n');
fprintf('READY!\n');
fprintf('Total devices processed: %d\n', length(unique_devices));
fprintf('Total files created: %d\n', total_files);
fprintf('The results have been saved in the folder: %s\n', output_dir);