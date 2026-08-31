function channels = jammed_channels(cfg, occupancy)
%JAMMED_CHANNELS Select a contiguous, centered partial-band subset.
nChannels = numel(cfg.channelOffsetsHz);
nJammed = round(occupancy * nChannels);
if occupancy < 0 || occupancy > 1 || abs(nJammed - occupancy*nChannels) > 1e-9
    error('fhss:Occupancy', 'Occupancy must map to an integer number of channels.');
end
if nJammed == 0
    channels = zeros(1, 0);
    return;
end
first = floor((nChannels - nJammed) / 2) + 1;
channels = first:first+nJammed-1;
end
