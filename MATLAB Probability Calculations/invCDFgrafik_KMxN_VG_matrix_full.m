clear; clc;
% A matrix is calculated for all specified MxN values

% fixed parameters
w=32;
Q=601080390;
L=2^w;
P_target=0.9;

% ranges
M_min = 1*10^8;
M_max = 1.5*10^10;
M_step = 10^7;
% N_min = 10;
% N_max = 40;
% N_step = 10;
N_values = [5, 10, 100, 500];

% Creating vectors
M_values = (M_min:M_step:M_max)';  % transpose it to turn it into a column
% N_values = (N_min:N_step:N_max)';  % transpose it to turn it into a column

% Creating a matrix
[M_matrix, N_matrix] = meshgrid(M_values, N_values);

% Calculate the probabilities for each element of the matrix
disp('Calculating probabilities...');
K_matrix = inv_P_K_cdf(P_target, Q, L, M_matrix, N_matrix);
disp('Ready!');

% Creating a table for output
T = array2table(K_matrix', ...
    'VariableNames', string(N_values), ...
    'RowNames', string(M_values));

% Creating file name
filename = sprintf('inv_matrix_results_KMxN_w%d_P_target%.2f.txt', w, P_target);

% Saving
writetable(T, filename, 'WriteRowNames', true, 'Delimiter', '\t');
disp(' ');
disp('Results are saved in the file: inv_matrix_results_KMxN_w%d_P_target%.2f.txt');