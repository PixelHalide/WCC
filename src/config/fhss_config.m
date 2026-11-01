function cfg = fhss_config(overrides)
%FHSS_CONFIG Return the complete, validated FHSS simulation configuration.
%   CFG = FHSS_CONFIG() returns the project defaults. CFG =
%   FHSS_CONFIG(OVERRIDES) recursively applies fields from a scalar struct.
%   Sample counts, frame length, and bandwidth are derived from primary fields.

if nargin < 1
    overrides = struct();
end
if ~isstruct(overrides) || ~isscalar(overrides)
    error('fhss:ConfigType', 'overrides must be a scalar struct.');
end

cfg.rfCenterHz = 2.4e9;
cfg.sampleRateHz = 500e3;
cfg.symbolRateHz = 10e3;
cfg.channelOffsetsHz = 1e3 * [-87.5 -62.5 -37.5 -12.5 12.5 37.5 62.5 87.5];
cfg.channelSpacingHz = 25e3;
cfg.preambleHex = '1ACFFC1D';
cfg.headerBits = 16;
cfg.payloadBits = 256;
cfg.crcBits = 16;
cfg.symbolsPerHop = 8;
cfg.hopStartIndex = 9; % Allows an acquisition search from -8 to +8 hops.
cfg.maxCodeOffset = 8;
cfg.syncHardMatchThreshold = 28;
cfg.syncMetricThreshold = 0.70;
cfg.seeds.hop = 7301;
cfg.seeds.payload = 1907;
cfg.seeds.noise = 4201;
cfg.seeds.jammer = 991;
cfg.seeds.timing = 6151;
cfg.defaultEbNoDb = 10;
cfg.defaultJammerOccupancy = 0.25;
cfg.defaultJsDb = 10;
cfg.experiment.ebNoDb = 0:2:14;
cfg.experiment.occupancies = [0 0.125 0.25 0.50];
cfg.experiment.symbolsPerHop = [16 8 4];
cfg.experiment.minPackets = 250;
cfg.experiment.maxPackets = 2000;
cfg.experiment.stopPacketErrors = 100;
cfg.experiment.mismatchRateErrors = [-0.02 -0.01 -0.005 0 0.005 0.01 0.02];
cfg.experiment.mismatchPackets = 200;
cfg.experiment.syncPackets = 50;
cfg.outputRoot = 'results';
cfg.figureRoot = fullfile('report', 'figures');

cfg = merge_structs(cfg, overrides);
% Keep dependent values consistent when callers change rates or frame sizes.
cfg.samplesPerSymbol = cfg.sampleRateHz / cfg.symbolRateHz;
cfg.channelNullToNullHz = 2 * cfg.symbolRateHz;
cfg.totalHoppingBandwidthHz = cfg.channelOffsetsHz(end) - ...
    cfg.channelOffsetsHz(1) + cfg.channelNullToNullHz;
cfg.preambleBits = int_to_bits(uint32(hex2dec(cfg.preambleHex)), 32);
cfg.frameBits = numel(cfg.preambleBits) + cfg.headerBits + cfg.payloadBits + cfg.crcBits;
validate_config(cfg);
end

function out = merge_structs(base, overrides)
out = base;
names = fieldnames(overrides);
for k = 1:numel(names)
    name = names{k};
    if isfield(out, name) && isstruct(out.(name)) && isstruct(overrides.(name))
        out.(name) = merge_structs(out.(name), overrides.(name));
    else
        out.(name) = overrides.(name);
    end
end
end

function validate_config(cfg)
validateattributes(cfg.sampleRateHz, {'numeric'}, {'scalar','positive','finite'});
validateattributes(cfg.symbolRateHz, {'numeric'}, {'scalar','positive','finite'});
validateattributes(cfg.samplesPerSymbol, {'numeric'}, {'scalar','integer','positive','finite'});
validateattributes(cfg.symbolsPerHop, {'numeric'}, {'scalar','integer','positive','finite'});
validateattributes(cfg.payloadBits, {'numeric'}, {'scalar','integer','positive','finite'});
validateattributes(cfg.channelOffsetsHz, {'numeric'}, {'row','nonempty','real','finite'});
if cfg.headerBits ~= 16 || cfg.crcBits ~= 16
    error('fhss:FrameFormat', 'The frame counter and CRC must both be 16 bits.');
end
if max(abs(cfg.channelOffsetsHz)) + cfg.channelNullToNullHz/2 >= cfg.sampleRateHz/2
    error('fhss:Aliasing', 'Channel main lobes must lie within the sampled band.');
end
if mod(cfg.frameBits, cfg.symbolsPerHop) ~= 0
    error('fhss:HopAlignment', 'frameBits must be divisible by symbolsPerHop.');
end
if any(diff(cfg.channelOffsetsHz) <= 0)
    error('fhss:HopSet', 'channelOffsetsHz must be strictly increasing.');
end
if cfg.hopStartIndex <= cfg.maxCodeOffset
    error('fhss:HopStart', 'hopStartIndex must be greater than maxCodeOffset.');
end
end
