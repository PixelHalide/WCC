function out = simulate_packet(cfg, scenario, mode)
%SIMULATE_PACKET Simulate one framed FHSS or fixed-frequency packet.
%   OUT = SIMULATE_PACKET(CFG, SCENARIO, MODE), where MODE is "waveform"
%   or "symbol". Symbol mode is the validated fast Monte Carlo abstraction.

if nargin < 1 || isempty(cfg)
    cfg = fhss_config();
end
if nargin < 2
    scenario = struct();
end
if nargin < 3
    mode = 'waveform';
end
scenario = scenario_defaults(cfg, scenario);
frame = build_frame(cfg, scenario.frameId, scenario.payload);

switch lower(char(mode))
    case 'waveform'
        out = simulate_waveform(cfg, frame, scenario);
    case 'symbol'
        out = simulate_symbols(cfg, frame, scenario);
    otherwise
        error('fhss:Mode', 'mode must be waveform or symbol.');
end
out.mode = char(mode);
out.scenario = scenario;
out.frame = frame;
end

function out = simulate_waveform(cfg, frame, scenario)
if ~strcmp(scenario.linkType, 'fhss')
    error('fhss:WaveformLink', 'Waveform mode currently models the FHSS link.');
end
tx = fhss_transmitter(cfg, frame.bits, scenario.symbolsPerHop, cfg.hopStartIndex);
dwellSamples = scenario.symbolsPerHop * cfg.samplesPerSymbol;
if isempty(scenario.timingOffsetSamples)
    timingStream = RandStream('mt19937ar', 'Seed', scenario.timingSeed);
    timingOffset = floor(rand(timingStream) * dwellSamples);
else
    timingOffset = scenario.timingOffsetSamples;
end
channel = apply_fhss_channel(cfg, tx.waveform, scenario, timingOffset);
options = struct('acquire', scenario.acquire, 'knownTimingSamples', timingOffset, ...
    'codeOffset', scenario.codeOffset, 'rateError', scenario.rateError);
receiver = fhss_receiver(cfg, channel.waveform, scenario.symbolsPerHop, options);
out = assemble_output(cfg, frame, receiver.payload, receiver.crcOk, ...
    receiver.syncSuccess, tx.hopIndices);
out.tx = tx;
out.channel = channel;
out.receiver = receiver;
end

function out = simulate_symbols(cfg, frame, scenario)
nSymbols = cfg.frameBits;
nHopsTx = ceil(nSymbols / scenario.symbolsPerHop);
txHopIndices = hop_sequence(cfg, nHopsTx, cfg.hopStartIndex);
txChannels = repelem(txHopIndices, scenario.symbolsPerHop);
txChannels = txChannels(1:nSymbols);
jamChannels = jammed_channels(cfg, scenario.jammerOccupancy);

switch scenario.linkType
    case 'fhss'
        txCarrier = txChannels;
        centers = (0:nSymbols-1) + 0.5;
        rxHopNumber = floor(centers ./ (scenario.symbolsPerHop * (1 + scenario.rateError))) + 1;
        rxHops = hop_sequence(cfg, max(rxHopNumber), cfg.hopStartIndex + scenario.codeOffset);
        rxCarrier = rxHops(rxHopNumber);
        desiredGain = double(rxCarrier == txCarrier);
    case 'fixed_jammed'
        if isempty(jamChannels)
            fixed = ceil(numel(cfg.channelOffsetsHz)/2);
        else
            fixed = jamChannels(1);
        end
        txCarrier = fixed * ones(1, nSymbols);
        desiredGain = ones(1, nSymbols);
    case 'fixed_clean'
        available = setdiff(1:numel(cfg.channelOffsetsHz), jamChannels);
        if isempty(available)
            error('fhss:FixedClean', 'No unjammed fixed channel is available.');
        end
        txCarrier = available(1) * ones(1, nSymbols);
        desiredGain = ones(1, nSymbols);
    case 'fixed_random'
        stream = RandStream('mt19937ar', 'Seed', scenario.hopSeed);
        fixed = randi(stream, numel(cfg.channelOffsetsHz));
        txCarrier = fixed * ones(1, nSymbols);
        desiredGain = ones(1, nSymbols);
    otherwise
        error('fhss:LinkType', 'Unknown linkType: %s', scenario.linkType);
end

symbols = 1 - 2*frame.bits;
noiseStream = RandStream('mt19937ar', 'Seed', scenario.noiseSeed);
if isfinite(scenario.ebNoDb)
    ebNo = 10^(scenario.ebNoDb/10);
    awgn = sqrt(1/(2*ebNo)) * randn(noiseStream, 1, nSymbols);
else
    awgn = zeros(1, nSymbols);
end
jammerDecision = zeros(1, nSymbols);
if ~isempty(jamChannels) && isfinite(scenario.jsDb)
    jammed = ismember(txCarrier, jamChannels);
    perChannelPower = 10^(scenario.jsDb/10) / numel(jamChannels);
    jammerStream = RandStream('mt19937ar', 'Seed', scenario.jammerSeed);
    jammerDecision(jammed) = sqrt(perChannelPower/2) * ...
        randn(jammerStream, 1, sum(jammed));
end
soft = desiredGain .* symbols + awgn + jammerDecision;
bits = double(soft < 0);
preambleMatches = sum(bits(1:numel(cfg.preambleBits)) == cfg.preambleBits);
syncSuccess = preambleMatches >= cfg.syncHardMatchThreshold;
p0 = numel(cfg.preambleBits);
h0 = p0 + cfg.headerBits;
p1 = h0 + cfg.payloadBits;
payload = bits(h0+1:p1);
crcOk = uint32(crc16_ccitt(bits(p0+1:p1))) == bits_to_uint(bits(p1+1:end));
out = assemble_output(cfg, frame, payload, crcOk, syncSuccess, txHopIndices);
out.symbol = struct('softSymbols', soft, 'bits', bits, 'txChannels', txCarrier, ...
    'desiredGain', desiredGain, 'jammedChannels', jamChannels, ...
    'preambleMatches', preambleMatches);
end

function out = assemble_output(cfg, frame, payload, crcOk, syncSuccess, hops)
if numel(payload) == cfg.payloadBits && all(isfinite(payload))
    bitErrors = sum(payload ~= frame.payload);
else
    bitErrors = cfg.payloadBits;
end
packetError = ~syncSuccess || ~crcOk;
out = struct('recoveredPayload', payload, 'crcOk', logical(crcOk), ...
    'syncSuccess', logical(syncSuccess), 'bitErrors', bitErrors, ...
    'ber', bitErrors/cfg.payloadBits, 'packetError', logical(packetError), ...
    'hopSchedule', hops);
end

function scenario = scenario_defaults(cfg, scenario)
defaults = struct('frameId', 0, 'payload', [], 'symbolsPerHop', cfg.symbolsPerHop, ...
    'ebNoDb', cfg.defaultEbNoDb, 'jammerOccupancy', cfg.defaultJammerOccupancy, ...
    'jsDb', cfg.defaultJsDb, 'linkType', 'fhss', 'acquire', true, ...
    'codeOffset', 0, 'rateError', 0, 'timingOffsetSamples', [], ...
    'noiseSeed', cfg.seeds.noise, 'jammerSeed', cfg.seeds.jammer, ...
    'timingSeed', cfg.seeds.timing, 'hopSeed', cfg.seeds.hop);
names = fieldnames(defaults);
for k = 1:numel(names)
    if ~isfield(scenario, names{k})
        scenario.(names{k}) = defaults.(names{k});
    end
end
if mod(cfg.frameBits, scenario.symbolsPerHop) ~= 0
    error('fhss:ScenarioHop', 'symbolsPerHop must divide the frame length.');
end
end
