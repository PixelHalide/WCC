function channel = apply_fhss_channel(cfg, txWaveform, scenario, timingOffsetSamples)
%APPLY_FHSS_CHANNEL Add a random timing guard, partial-band jammer, and AWGN.

if nargin < 4
    timingOffsetSamples = 0;
end
rxLength = timingOffsetSamples + numel(txWaveform);
desired = [zeros(1, timingOffsetSamples) txWaveform];
n = 0:rxLength-1;

jamChannels = jammed_channels(cfg, scenario.jammerOccupancy);
jammer = zeros(1, rxLength);
if ~isempty(jamChannels) && isfinite(scenario.jsDb)
    stream = RandStream('mt19937ar', 'Seed', scenario.jammerSeed);
    nSymbols = ceil(rxLength / cfg.samplesPerSymbol);
    totalJammerPower = 10^(scenario.jsDb/10);
    perChannelPower = totalJammerPower / numel(jamChannels);
    for channelIndex = jamChannels
        symbols = (randn(stream, 1, nSymbols) + 1j*randn(stream, 1, nSymbols)) / sqrt(2);
        shaped = repelem(symbols, cfg.samplesPerSymbol);
        shaped = shaped(1:rxLength);
        carrier = exp(1j * 2*pi * cfg.channelOffsetsHz(channelIndex) .* n / cfg.sampleRateHz);
        jammer = jammer + sqrt(perChannelPower) .* shaped .* carrier;
    end
end

noise = zeros(1, rxLength);
if isfinite(scenario.ebNoDb)
    stream = RandStream('mt19937ar', 'Seed', scenario.noiseSeed);
    ebNo = 10^(scenario.ebNoDb/10);
    complexVariance = cfg.samplesPerSymbol / ebNo;
    noise = sqrt(complexVariance/2) .* ...
        (randn(stream, 1, rxLength) + 1j*randn(stream, 1, rxLength));
end

channel = struct('waveform', desired + jammer + noise, 'desired', desired, ...
    'jammer', jammer, 'noise', noise, 'jammedChannels', jamChannels, ...
    'timingOffsetSamples', timingOffsetSamples);
end
