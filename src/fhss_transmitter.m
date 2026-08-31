function tx = fhss_transmitter(cfg, frameBits, symbolsPerHop, startHop)
%FHSS_TRANSMITTER BPSK-map and frequency-hop one complete frame.

if nargin < 3
    symbolsPerHop = cfg.symbolsPerHop;
end
if nargin < 4
    startHop = cfg.hopStartIndex;
end
frameBits = double(frameBits(:).');
symbols = 1 - 2 * frameBits;
baseband = repelem(symbols, cfg.samplesPerSymbol);
[channelBySample, hopIndices] = carrier_schedule(cfg, numel(baseband), ...
    symbolsPerHop, startHop, 0);
frequencies = cfg.channelOffsetsHz(channelBySample);
n = 0:numel(baseband)-1;
oscillator = exp(1j * 2*pi .* frequencies .* n / cfg.sampleRateHz);
waveform = baseband .* oscillator;
tx = struct('waveform', waveform, 'baseband', baseband, 'symbols', symbols, ...
    'channelBySample', channelBySample, 'frequencyBySampleHz', frequencies, ...
    'hopIndices', hopIndices(1:ceil(numel(symbols)/symbolsPerHop)), ...
    'symbolsPerHop', symbolsPerHop, 'startHop', startHop);
end
