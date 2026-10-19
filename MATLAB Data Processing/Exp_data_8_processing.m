%% Script for extracting PUF data for ALL devices
clear; close all; clc;

%% 1. Data loading
filename = 'puf_measurements_202605141543_48000.csv';
data = readtable(filename, 'PreserveVariableNames', true);

%% 2. Creating the main folder
output_dir = 'extracted_puf_data_all';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

%% 3. We obtain unique devices
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
    
    % We process each dimension
    for i = 1:height(device_data)
        dump_idx = device_data.dump_index(i);
        start_addr = device_data.puf_addr(i);
        puf_len = device_data.puf_len(i);
        hex_str = device_data.puf_data_hex{i};
        
        % Extracting bytes
        num_bytes = floor(length(hex_str) / 2);
        addresses = start_addr + (0:num_bytes-1)';
        memory_values = cell(num_bytes, 1);
        
        for j = 1:num_bytes
            byte_hex = hex_str((j-1)*2 + 1 : j*2);
            memory_values{j} = byte_hex;
        end
        
        % Creating a table
        result_table = table((1:num_bytes)', addresses, memory_values, ...
            'VariableNames', {'Index', 'Address', 'Value'});
        
        % Saving to a file
        output_filename = sprintf('%s_dump_%02d.txt', safe_device_name, dump_idx);
        output_path = fullfile(device_folder, output_filename);
        
        fid = fopen(output_path, 'w');
        fprintf(fid, '# PUF Data Extraction Report\n');
        fprintf(fid, '# Device ID: %s\n', target_device);
        fprintf(fid, '# Dump Index: %d\n', dump_idx);
        fprintf(fid, '# Start Address: 0x%X\n', start_addr);
        fprintf(fid, '# Total Bytes: %d\n', num_bytes);
        fprintf(fid, '# Expected Bytes (puf_len): %d\n', puf_len);
        fprintf(fid, '# Format: Index | Address (Hex) | Value (Hex)\n');
        fprintf(fid, '#------------------------------------------------\n');
        
        for j = 1:height(result_table)
            fprintf(fid, '%d\t0x%X\t%s\n', ...
                result_table.Index(j), ...
                result_table.Address(j), ...
                result_table.Value{j});
        end
        
        fclose(fid);
        
        % Examination
        if num_bytes ~= puf_len
            fprintf('  Warning: Dump %d - %d bytes, was expected %d\n', ...
                dump_idx, num_bytes, puf_len);
        end
        
        total_files = total_files + 1;
    end
    
    fprintf('Device %s is processed. Files created: %d\n', ...
        target_device, height(device_data));
end

fprintf('\n========================================\n');
fprintf('READY!\n');
fprintf('Total devices processed: %d\n', length(unique_devices));
fprintf('Total files created: %d\n', total_files);
fprintf('The results have been saved in the folder: %s\n', output_dir);