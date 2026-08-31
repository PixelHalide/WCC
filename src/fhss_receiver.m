function rxOut = fhss_receiver(cfg, waveform, symbolsPerHop, options)
%FHSS_RECEIVER Synchronize, dehop, demodulate, parse, and CRC-check a frame.

if nargin < 4
    options = struct();
end
options = receiver_defaults(options);
if options.acquire
    sync = acquire_hop_sync(cfg, waveform, symbolsPerHop);
else
    sync = struct('success', true, 'timingOffsetSamples', options.knownTimingSamples, ...
        'codeOffset', options.codeOffset, 'metric', NaN, 'hardMatches', NaN, ...
        'softPreamble', []);
end

[soft, bits, debug] = dehop_and_demodulate(cfg, waveform, ...
    sync.timingOffsetSamples, cfg.frameBits, symbolsPerHop, ...
    cfg.hopStartIndex + sync.codeOffset, options.rateError);
[frameStart, preambleMatches] = locate_preamble(bits, cfg.preambleBits);
if isnan(frameStart) || frameStart + cfg.frameBits - 1 > numel(bits)
    frameStart = 1;
    frameBits = bits;
    parseValid = false;
else
    frameBits = bits(frameStart:frameStart+cfg.frameBits-1);
    parseValid = true;
end

p0 = numel(cfg.preambleBits);
h0 = p0 + cfg.headerBits;
payloadEnd = h0 + cfg.payloadBits;
if numel(frameBits) >= cfg.frameBits
    header = frameBits(p0+1:h0);
    payload = frameBits(h0+1:payloadEnd);
    receivedCrcBits = frameBits(payloadEnd+1:payloadEnd+cfg.crcBits);
    calculatedCrc = crc16_ccitt([header payload]);
    receivedCrc = bits_to_uint(receivedCrcBits);
    crcOk = uint32(calculatedCrc) == receivedCrc;
    frameId = double(bits_to_uint(header));
else
    header = [];
    payload = nan(1, cfg.payloadBits);
    receivedCrcBits = [];
    calculatedCrc = uint16(0);
    receivedCrc = uint32(0);
    crcOk = false;
    frameId = NaN;
end

frameSyncOk = parseValid && preambleMatches >= cfg.syncHardMatchThreshold;
if options.acquire
    syncSuccess = sync.success && frameSyncOk;
else
    syncSuccess = frameSyncOk;
end
rxOut = struct('bits', bits, 'softSymbols', soft, 'frameBits', frameBits, ...
    'frameStart', frameStart, 'preambleMatches', preambleMatches, ...
    'frameSyncOk', frameSyncOk, 'syncSuccess', syncSuccess, 'sync', sync, ...
    'header', header, 'payload', payload, 'frameId', frameId, ...
    'receivedCrcBits', receivedCrcBits, 'receivedCrc', receivedCrc, ...
    'calculatedCrc', calculatedCrc, 'crcOk', crcOk, 'debug', debug);
end

function options = receiver_defaults(options)
defaults = struct('acquire', true, 'knownTimingSamples', 0, ...
    'codeOffset', 0, 'rateError', 0);
names = fieldnames(defaults);
for k = 1:numel(names)
    if ~isfield(options, names{k})
        options.(names{k}) = defaults.(names{k});
    end
end
end
