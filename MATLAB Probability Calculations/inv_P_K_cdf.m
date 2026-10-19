% Solving the inverse problem: finding the minimum K for a given probability
% For large parameter values, we use an approximation based on the
% central limit theorem
function K = inv_P_K_cdf(P_target, Q, L, M, N)


    
% Resizing inputs to a common shape for broadcasting
% this allows for the combination of scalars and arrays of arbitrary shape
% [K, Q, L, M, N] = ndgrid(K, Q, L, M, N);

    % Calculation of moments
    p = (1 - (1 - 1./L).^M).^N;   % Probability of success across all N sets
    
    p2 = (1 - 2.*(1-1./L).^M + (1-2./L).^M).^N; % Probability of success for a couple
    mu = Q .* p;
    var_X = Q .* p .* (1-p) + Q.*(Q-1) .* (p2 - p.^2);
    
    % Protection against negative variance due to numerical errors

    % Logical mask for elements with small negative variance
    mask_negative_small = (var_X < 0) & (var_X > -1e-10);
    var_X(mask_negative_small) = 0;
    
  
    
    sigma = sqrt(var_X);
    
    % Calculate K using the inverse normal distribution function 
    % K = mu + 0.5 + sigma * norminv(1 - P)
    z = norminv(1 - P_target); 
    K = mu + 0.5 + sigma .* z;
    
 
   % Rounding to an integer (minimum K that ensures the probability)
    K = floor(K);
    
   % Constraining K to permissible limits
    K = max(K, 1);           % K >= 1
    K = min(K, Q);           % K <= Q
    
    % Reshaping the output to match the original shape of the inputs
    K = squeeze(K);
end

