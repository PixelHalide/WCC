function interval = wilson_interval(errors, trials, confidence)
%WILSON_INTERVAL Wilson score interval for a binomial proportion.
if nargin < 3
    confidence = 0.95;
end
if trials == 0
    interval = [NaN NaN];
    return;
end
if abs(confidence - 0.95) > eps
    error('fhss:WilsonConfidence', 'This base-MATLAB implementation supports 95%% intervals.');
end
z = 1.95996398454005;
p = errors / trials;
denominator = 1 + z^2/trials;
center = (p + z^2/(2*trials)) / denominator;
half = z/denominator * sqrt(p*(1-p)/trials + z^2/(4*trials^2));
interval = [max(0, center-half), min(1, center+half)];
end
