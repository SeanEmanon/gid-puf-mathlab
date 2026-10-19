clear; clc;
% A matrix is calculated for all specified MxK values.

% fixed parameters
w=32;
Q=601080390;
L=2^w;
N=500;

% ranges
M_min = 1.4*10^10;
M_max = 1.5*10^10;
M_step = 10^6;
K_min = 10;
K_max = 40;
K_step = 10;

% Creating vectors
M_values = (M_min:M_step:M_max)';  % transpose it to turn it into a column
K_values = (K_min:K_step:K_max)';  % transpose it to turn it into a column
% Creating a matrix
[M_matrix, K_matrix] = meshgrid(M_values, K_values);

% Calculate the probabilities for each element of the matrix
disp('Calculating probabilities...');
q_matrix = P_K_cdf(K_matrix, Q, L, M_matrix, N);
disp('Ready!');

% Create a table for output
T = array2table(q_matrix', ...
    'VariableNames', string(K_values), ...
    'RowNames', string(M_values));

% Generating a filename
filename = sprintf('full_matrix_results_qMxK_w%d_N%d.txt', w, N);

% Saving
writetable(T, filename, 'WriteRowNames', true, 'Delimiter', '\t');
disp(' ');
disp('The results have been saved to a file: full_matrix_results_qMxK_w%d_N%d.txt');