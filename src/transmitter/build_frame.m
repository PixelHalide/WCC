function frame = build_frame(cfg, frameId, payload)
%BUILD_FRAME Construct preamble, header, payload, and CRC fields.

if nargin < 2
    frameId = 0;
end
if nargin < 3 || isempty(payload)
    stream = RandStream('mt19937ar', 'Seed', cfg.seeds.payload + double(frameId));
    payload = randi(stream, 2, 1, cfg.payloadBits) - 1;
end
payload = double(payload(:).');
if numel(payload) ~= cfg.payloadBits || any(payload ~= 0 & payload ~= 1)
    error('fhss:Payload', 'Payload must contain exactly %d bits.', cfg.payloadBits);
end
header = int_to_bits(uint16(mod(double(frameId), 65536)), cfg.headerBits);
protected = [header payload];
crcValue = crc16_ccitt(protected);
crcBits = int_to_bits(crcValue, cfg.crcBits);
bits = [cfg.preambleBits protected crcBits];
frame = struct('bits', bits, 'preamble', cfg.preambleBits, 'header', header, ...
    'payload', payload, 'crcBits', crcBits, 'crcValue', crcValue, ...
    'frameId', mod(double(frameId), 65536));
end
