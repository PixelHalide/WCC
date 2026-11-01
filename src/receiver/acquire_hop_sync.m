function sync = acquire_hop_sync(cfg, rx, symbolsPerHop)
%ACQUIRE_HOP_SYNC Jointly estimate packet timing and hopping-code phase.
%   The search covers every sample in one dwell and +/-maxCodeOffset. An
%   exhaustive timing search is robust to the carrier-dependent phase change
%   that can make a symbol-spaced coarse search miss the correct sample.

dwellSamples = symbolsPerHop * cfg.samplesPerSymbol;
offsets = -cfg.maxCodeOffset:cfg.maxCodeOffset;
templates = build_templates(cfg, symbolsPerHop, offsets);
best = empty_sync();
for timing = 0:dwellSamples-1
    for index = 1:numel(offsets)
        candidate = score_candidate(cfg, rx, timing, offsets(index), templates{index});
        if candidate.metric > best.metric
            best = candidate;
        end
    end
end
best.success = best.hardMatches >= cfg.syncHardMatchThreshold && ...
    best.metric >= cfg.syncMetricThreshold;
sync = best;
end

function templates = build_templates(cfg, symbolsPerHop, offsets)
nSymbols = numel(cfg.preambleBits);
nSamples = nSymbols * cfg.samplesPerSymbol;
n = 0:nSamples-1;
templates = cell(size(offsets));
for index = 1:numel(offsets)
    channels = carrier_schedule(cfg, nSamples, symbolsPerHop, ...
        cfg.hopStartIndex + offsets(index), 0);
    frequencies = cfg.channelOffsetsHz(channels);
    templates{index} = exp(-1j * 2*pi .* frequencies .* n / cfg.sampleRateHz);
end
end

function result = score_candidate(cfg, rx, timing, codeOffset, oscillator)
nSymbols = numel(cfg.preambleBits);
nSamples = nSymbols * cfg.samplesPerSymbol;
first = timing + 1;
last = timing + nSamples;
if first < 1 || last > numel(rx)
    result = empty_sync();
    result.timingOffsetSamples = timing;
    result.codeOffset = codeOffset;
    return;
end
dehopped = rx(first:last) .* oscillator;
soft = real(mean(reshape(dehopped, cfg.samplesPerSymbol, nSymbols), 1));
bits = double(soft < 0);
known = 1 - 2*cfg.preambleBits;
denominator = sqrt(sum(abs(soft).^2) * sum(known.^2)) + eps;
metric = real(sum(soft .* known)) / denominator;
result = struct('success', false, 'timingOffsetSamples', timing, ...
    'codeOffset', codeOffset, 'metric', metric, ...
    'hardMatches', sum(bits == cfg.preambleBits), 'softPreamble', soft);
end

function sync = empty_sync()
sync = struct('success', false, 'timingOffsetSamples', 0, 'codeOffset', 0, ...
    'metric', -Inf, 'hardMatches', 0, 'softPreamble', []);
end
