%% Script for collisions search
clear; close all; clc;

% 1. Request the folder containing device files
folder_path = uigetdir(pwd, 'Select the folder containing device files');
if folder_path == 0
    disp('No folder selected. Operation complete.');
    return;
end

% 2. Get a list of all .txt files (one per device)
files = dir(fullfile(folder_path, '*.txt'));
if isempty(files)
    error('There are no files in the selected folder.txt');
end
% Sorting by name for a fixed device order
[~, idx] = sort({files.name});
files = files(idx);
num_devices = length(files);
fprintf('Devices found: %d\n', num_devices);

% 3. Reading each file and building a mapping: value -> first address
device_maps = cell(num_devices, 1);    % containers.Map for each device
device_ids  = cell(num_devices, 1);    % Device ID from the # Device: line

for d = 1:num_devices
    filename = fullfile(folder_path, files(d).name);
    fprintf('Read %d/%d: %s\n', d, num_devices, files(d).name);
    
    % Open the file and skip comments, but keep track of # Device:
    fid = fopen(filename, 'r');
    if fid == -1
        error('Failed to open file: %s', filename);
    end
    
    device_id = '';
    data_lines = {};
    while ~feof(fid)
        line = fgetl(fid);
        if isempty(line)
            continue;
        end
        line = strtrim(line);
       % Searching for a line with # Device:
        if startsWith(line, '# Device:')
            % Extract the ID (everything after "# Device: ")
            parts = split(line, '# Device:');
            if length(parts) >= 2
                device_id = strtrim(parts{2});
            end
        end
        % Skip empty lines and comment lines, except for the already processed # Device
        if isempty(line) || line(1) == '#'
            continue;
        end
        data_lines{end+1} = line;
    end
    fclose(fid);
    
    if isempty(device_id)
        warning('The string "# Device:" was not found in file %s. Using the filename.', files(d).name);
        device_id = files(d).name;
    else
        fprintf('  Device ID: %s\n', device_id);
    end
    device_ids{d} = device_id;
    
    % Parsing data rows: 3 columns expected (Index, Address, Value)
    addresses = {};
    values = {};
    for i = 1:length(data_lines)
        parts = strsplit(data_lines{i}, sprintf('\t'));
        if length(parts) < 3
            parts = strsplit(data_lines{i});  % whitespace separator
        end
        if length(parts) >= 3
            addresses{end+1} = parts{2};  % column Address
            values{end+1}   = parts{3};  % column Value
        else
            warning('A line with an incorrect format was skipped: %s', data_lines{i});
        end
    end
    
    % Creating a Map: key = value (string), value = first address
    val_to_addr = containers.Map('KeyType', 'char', 'ValueType', 'char');
    for i = 1:length(values)
        v = values{i};
        if ~val_to_addr.isKey(v)
            val_to_addr(v) = addresses{i};
        end
    end
    device_maps{d} = val_to_addr;
end

% 4. Collecting all unique values ​​from all devices
all_values = {};
for d = 1:num_devices
    current_keys = keys(device_maps{d});
    all_values = [all_values; current_keys(:)];   % force column
end
unique_values = unique(all_values);
fprintf('Total number of distinct responses: %d\n', length(unique_values));

% 5. Collision search
collision_vals = {};
collision_addrs = {};  % cell: an array of device addresses for each value

for i = 1:length(unique_values)
    val = unique_values{i};
    cnt = 0;
    addrs = cell(num_devices, 1);
    for d = 1:num_devices
        if device_maps{d}.isKey(val)
            cnt = cnt + 1;
            addrs{d} = device_maps{d}(val);
        else
            addrs{d} = '';   
        end
    end
    if cnt == num_devices   % the value must be present on ALL devices
        collision_vals{end+1} = val;
        collision_addrs{end+1} = addrs;
    end
end

num_collisions = length(collision_vals);
fprintf('Collisions found: %d\n', num_collisions);

if num_collisions == 0
    disp('No collisions detected.');
    return;
end

% 6. Writing results to the file collisions.txt
output_file = fullfile(folder_path, 'collisions.txt');
fid = fopen(output_file, 'w');
if fid == -1
    error('Failed to create output file');
end

% Heading
fprintf(fid, '# Collisions Report\n');
fprintf(fid, '# Generated: %s\n', datestr(now));
fprintf(fid, '# Number of devices: %d\n', num_devices);
fprintf(fid, '# Number of collisions: %d\n', num_collisions);
% fprintf(fid, '# Format: Index\tValue\t');
fprintf(fid, '# Index\tValue\t');
for d = 1:num_devices
    % We use the extracted device ID instead of the filename.
    if d < num_devices
        fprintf(fid, '%s\t', device_ids{d});
    else
        fprintf(fid, '%s\n', device_ids{d});
    end
end
fprintf(fid, '#------------------------------------------------\n');

% Data
for ci = 1:num_collisions
    fprintf(fid, '%d\t%s\t', ci, collision_vals{ci});
    addrs = collision_addrs{ci};
    for d = 1:num_devices
        if isempty(addrs{d})
            fprintf(fid, '-');
        else
            fprintf(fid, '%s', addrs{d});
        end
        if d < num_devices
            fprintf(fid, '\t');
        else
            fprintf(fid, '\n');
        end
    end
end

fclose(fid);
fprintf('The result has been saved to the file:\n%s\n', output_file);