function bits = bytes_to_bits(bytes)
%BYTES_TO_BITS Convert uint8 values to a big-endian row of bits.
bytes = uint8(bytes(:).');
bits = zeros(1, 8 * numel(bytes));
for k = 1:numel(bytes)
    bits((k-1)*8 + (1:8)) = int_to_bits(bytes(k), 8);
end
end
