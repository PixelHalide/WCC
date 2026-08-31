function [channelBySample, hopIndices] = carrier_schedule(cfg, nSamples, symbolsPerHop, startHop, rateError)
%CARRIER_SCHEDULE Build the receiver/transmitter hop schedule at sample rate.

if nargin < 4
    startHop = cfg.hopStartIndex;
end
if nargin < 5
    rateError = 0;
end
nominalDwell = symbolsPerHop * cfg.samplesPerSymbol;
receiverDwell = nominalDwell * (1 + rateError);
if receiverDwell <= 0
    error('fhss:Dwell', 'Receiver dwell must be positive.');
end
nHops = ceil(nSamples / receiverDwell) + 2;
hopIndices = hop_sequence(cfg, nHops, startHop);
channelBySample = zeros(1, nSamples);
for h = 1:nHops
    first = round((h-1) * receiverDwell) + 1;
    last = min(nSamples, round(h * receiverDwell));
    if first <= nSamples && first <= last
        channelBySample(first:last) = hopIndices(h);
    end
end
if any(channelBySample == 0)
    % Fill rare gaps caused by defensive rounding with the previous channel.
    for k = 1:nSamples
        if channelBySample(k) == 0
            if k == 1
                channelBySample(k) = hopIndices(1);
            else
                channelBySample(k) = channelBySample(k-1);
            end
        end
    end
end
end
