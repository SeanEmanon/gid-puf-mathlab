% For large parameter values, we use an approximation based on the
% central limit theorem
function P = P_K_cdf(K, Q, L, M, N)



    % Calculation of moments
    p = (1 - (1 - 1./L).^M).^N;   % Probability of success across all N sets
    
    p2 = (1 - 2.*(1-1./L).^M + (1-2./L).^M).^N; % Probability of success for a couple
    mu = Q .* p;
    var_X = Q .* p .* (1-p) + Q.*(Q-1) .* (p2 - p.^2);
    
    % Protection against negative variance due to numerical errors
     
    % Logical mask for elements with small negative variance
    mask_negative_small = (var_X < 0) & (var_X > -1e-10);
    var_X(mask_negative_small) = 0;
    
    % Error for significant negative variance
    if any(var_X < -1e-10, 'all')
        error('Negative variance in %d elements', nnz(var_X < -1e-10));
    end
    
    sigma = sqrt(var_X);
    
    % Normal approximation with continuity correction
    % Initialization of the result
    P = zeros(size(mu));
    
    %    Case 1: sigma == 0 (degenerate distribution)
    mask_sigma_zero = (sigma == 0);
    P(mask_sigma_zero) = double(mu(mask_sigma_zero) >= K(mask_sigma_zero) - 0.5);
    
    %    Case 2: sigma > 0 (standard normal approximation)
    mask_sigma_pos = ~mask_sigma_zero;
    z = zeros(size(mu));
    z(mask_sigma_pos) = (K(mask_sigma_pos) - 0.5 - mu(mask_sigma_pos)) ./ sigma(mask_sigma_pos);
    P(mask_sigma_pos) = 1 - normcdf(z(mask_sigma_pos));
    
    
    P = squeeze(P);

end