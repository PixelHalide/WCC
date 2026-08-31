function hops = hop_sequence(cfg, count, startIndex)
%HOP_SEQUENCE Reproduce a balanced seeded pseudo-random hopping sequence.

if nargin < 3
    startIndex = cfg.hopStartIndex;
end
if count < 0 || startIndex < 1 || fix(count) ~= count || fix(startIndex) ~= startIndex
    error('fhss:HopArguments', 'count and startIndex must be nonnegative/positive integers.');
end
nChannels = numel(cfg.channelOffsetsHz);
needed = startIndex + count - 1;
nBlocks = ceil(needed / nChannels);
stream = RandStream('mt19937ar', 'Seed', cfg.seeds.hop);
sequence = zeros(1, nBlocks * nChannels);
for b = 1:nBlocks
    sequence((b-1)*nChannels + (1:nChannels)) = randperm(stream, nChannels);
end
hops = sequence(startIndex:startIndex + count - 1);
end
