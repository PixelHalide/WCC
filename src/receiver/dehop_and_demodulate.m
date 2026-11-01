function [softSymbols, bits, debug] = dehop_and_demodulate(cfg, rx, startSample, ...
    nSymbols, symbolsPerHop, startHop, rateError)
%DEHOP_AND_DEMODULATE Mix down a candidate schedule and integrate symbols.

if nargin < 7
    rateError = 0;
end
nSamples = nSymbols * cfg.samplesPerSymbol;
first = startSample + 1;
last = startSample + nSamples;
if first < 1 || last > numel(rx)
    softSymbols = nan(1, nSymbols);
    bits = ones(1, nSymbols);
    debug = struct('valid', false, 'dehopped', []);
    return;
end
segment = rx(first:last);
[channels, hopIndices] = carrier_schedule(cfg, nSamples, symbolsPerHop, startHop, rateError);
frequencies = cfg.channelOffsetsHz(channels);
n = 0:nSamples-1;
oscillator = exp(-1j * 2*pi .* frequencies .* n / cfg.sampleRateHz);
dehopped = segment .* oscillator;
matrix = reshape(dehopped, cfg.samplesPerSymbol, nSymbols);
softSymbols = real(mean(matrix, 1));
bits = double(softSymbols < 0);
debug = struct('valid', true, 'dehopped', dehopped, 'channels', channels, ...
    'hopIndices', hopIndices, 'frequenciesHz', frequencies);
end
