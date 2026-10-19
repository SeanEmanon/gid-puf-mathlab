clear; clc;
% A matrix is calculated for all specified NxK values

% fixed parameters
w=32;
Q=601080390;
L=2^w;
M=7.9*10^9;

% ranges
N_min = 10;
N_max = 200;
N_step = 1;
K_min = 10;
K_max = 40;
K_step = 10;

% Creating vectors
N_values = (N_min:N_step:N_max)';  % transpose it to turn it into a column
K_values = (K_min:K_step:K_max)';  % transpose it to turn it into a column

% Creating a matrix
[N_matrix, K_matrix] = meshgrid(N_values, K_values);

% Calculate the probabilities for each element of the matrix
disp('Calculating probabilities...');
q_matrix = P_K_cdf(K_matrix, Q, L, M, N_matrix);
disp('Ready!');

% Create a table for output
T = array2table(q_matrix', ...
    'VariableNames', string(K_values), ...
    'RowNames', string(N_values));

% Generating a filename
filename = sprintf('full_matrix_results_qNxK_w%d_M%e.txt', w, M);

% Saving
writetable(T, filename, 'WriteRowNames', true, 'Delimiter', '\t');
disp(' ');
disp('The results have been saved to a file: full_matrix_results_qNxK_w%d_M%e.txt');