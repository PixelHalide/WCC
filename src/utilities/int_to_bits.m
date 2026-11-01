function bits = int_to_bits(value, width)
%INT_TO_BITS Convert an unsigned scalar to a big-endian row of bits.
bits = zeros(1, width);
for k = 1:width
    bits(k) = bitget(value, width - k + 1);
end
end
