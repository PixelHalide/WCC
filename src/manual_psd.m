function [powerDb, frequenciesHz] = manual_psd(x, sampleRateHz, segmentLength, overlap, nfft)
%MANUAL_PSD Base-MATLAB averaged periodogram for a complex waveform.
x = x(:).';
step = segmentLength - overlap;
nFrames = max(1, floor((numel(x)-overlap)/step));
window = 0.5 - 0.5*cos(2*pi*(0:segmentLength-1)/(segmentLength-1));
accumulator = zeros(1, nfft);
for k = 1:nFrames
    first = (k-1)*step + 1;
    segment = zeros(1, segmentLength);
    available = min(segmentLength, numel(x)-first+1);
    if available > 0
        segment(1:available) = x(first:first+available-1);
    end
    transformed = fftshift(fft(segment .* window, nfft));
    accumulator = accumulator + abs(transformed).^2 / sum(window.^2);
end
power = accumulator/nFrames;
powerDb = 10*log10(power/(max(power)+eps) + eps);
frequenciesHz = (-nfft/2:nfft/2-1) * sampleRateHz/nfft;
end
