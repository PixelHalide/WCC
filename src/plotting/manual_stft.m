function [powerDb, frequenciesHz, timesSeconds] = manual_stft(x, sampleRateHz, windowLength, overlap, nfft)
%MANUAL_STFT Base-MATLAB short-time Fourier transform and normalized power.
x = x(:).';
step = windowLength - overlap;
nFrames = max(1, floor((numel(x) - overlap) / step));
window = 0.5 - 0.5*cos(2*pi*(0:windowLength-1)/(windowLength-1));
spectrum = zeros(nfft, nFrames);
timesSeconds = zeros(1, nFrames);
for k = 1:nFrames
    first = (k-1)*step + 1;
    segment = zeros(1, windowLength);
    available = min(windowLength, numel(x)-first+1);
    if available > 0
        segment(1:available) = x(first:first+available-1);
    end
    spectrum(:,k) = fftshift(fft(segment .* window, nfft)).';
    timesSeconds(k) = (first - 1 + windowLength/2) / sampleRateHz;
end
power = abs(spectrum).^2;
powerDb = 10*log10(power/(max(power(:))+eps) + eps);
frequenciesHz = (-nfft/2:nfft/2-1) * sampleRateHz/nfft;
end
