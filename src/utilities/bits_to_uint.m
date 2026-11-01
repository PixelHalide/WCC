function value = bits_to_uint(bits)
%BITS_TO_UINT Convert up to 32 big-endian bits to uint32.
bits = double(bits(:).');
if numel(bits) > 32 || any(bits ~= 0 & bits ~= 1)
    error('fhss:BitsToUint', 'Input must contain at most 32 binary values.');
end
value = uint32(0);
for k = 1:numel(bits)
    value = bitor(bitshift(value, 1), uint32(bits(k)));
end
end
