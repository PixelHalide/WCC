function crc = crc16_ccitt(dataBits)
%CRC16_CCITT CRC-16/CCITT-FALSE over a row of big-endian bits.
%   Polynomial 0x1021, initial value 0xFFFF, no reflection, xorout 0.

dataBits = double(dataBits(:).');
if any(dataBits ~= 0 & dataBits ~= 1)
    error('fhss:CRCInput', 'CRC input must be binary.');
end
reg = uint16(hex2dec('FFFF'));
poly = uint16(hex2dec('1021'));
for bit = dataBits
    feedback = xor(bitget(reg, 16) ~= 0, bit ~= 0);
    reg = bitshift(reg, 1);
    if feedback
        reg = bitxor(reg, poly);
    end
end
crc = reg;
end
