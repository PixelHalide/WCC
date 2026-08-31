function [index, matches] = locate_preamble(bits, preamble)
%LOCATE_PREAMBLE Find the highest-Hamming-match preamble location.
bits = double(bits(:).');
preamble = double(preamble(:).');
n = numel(bits) - numel(preamble) + 1;
if n < 1
    index = NaN;
    matches = 0;
    return;
end
scores = zeros(1, n);
for k = 1:n
    scores(k) = sum(bits(k:k+numel(preamble)-1) == preamble);
end
[matches, index] = max(scores);
end
