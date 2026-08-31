function plot_demo(cfg, demo)
%PLOT_DEMO Produce waveform, hopping, spectrum, and system evidence.
if ~exist(cfg.figureRoot, 'dir'), mkdir(cfg.figureRoot); end
tx = demo.tx;
channel = demo.channel;
sph = demo.scenario.symbolsPerHop;
dwell = sph/cfg.symbolRateHz;
nHops = numel(tx.hopIndices);

fig = figure('Visible','off','Color','w','Position',[100 100 900 420]);
stairs((0:nHops-1)*dwell*1e3, cfg.channelOffsetsHz(tx.hopIndices)/1e3, ...
    'LineWidth',1.4);
xlabel('Time (ms)'); ylabel('Carrier offset (kHz)');
title('Reproducible FHSS hop pattern'); grid on;
ylim([min(cfg.channelOffsetsHz) max(cfg.channelOffsetsHz)]/1e3 + [-10 10]);
export_figure_pair(fig, cfg.figureRoot, 'hop_pattern');

hopNumber = (1:nHops).';
hopChannels = tx.hopIndices(:);
hopOffsetsKHz = reshape(cfg.channelOffsetsHz(hopChannels), [], 1)/1e3;
hopTable = table(hopNumber, hopChannels, hopOffsetsKHz, ...
    (hopNumber-1)*dwell*1e3, hopNumber*dwell*1e3, ...
    'VariableNames', {'Hop','Channel','OffsetKHz','StartMs','EndMs'});
writetable(hopTable, fullfile(cfg.outputRoot, 'baseline_hop_table.csv'));

samplesShown = min(numel(tx.waveform), 4*sph*cfg.samplesPerSymbol);
t = (0:samplesShown-1)/cfg.sampleRateHz*1e3;
fig = figure('Visible','off','Color','w','Position',[100 100 900 520]);
subplot(2,1,1); plot(t, real(tx.waveform(1:samplesShown)), 'LineWidth',0.8);
ylabel('Real amplitude'); title('FHSS transmit waveform (first four hops)'); grid on;
subplot(2,1,2); plot(t, tx.frequencyBySampleHz(1:samplesShown)/1e3, 'LineWidth',1.2);
xlabel('Time (ms)'); ylabel('Offset (kHz)'); grid on;
export_figure_pair(fig, cfg.figureRoot, 'transmit_waveform');

[txStft, f, stftTime] = manual_stft(tx.waveform, cfg.sampleRateHz, 256, 192, 1024);
rxPacket = channel.waveform(channel.timingOffsetSamples+1:end);
[rxStft, ~, ~] = manual_stft(rxPacket, cfg.sampleRateHz, 256, 192, 1024);
fig = figure('Visible','off','Color','w','Position',[100 100 950 650]);
subplot(2,1,1); imagesc(stftTime*1e3, f/1e3, txStft); axis xy;
ylim([-130 130]); caxis([-45 0]); colorbar; ylabel('Offset (kHz)');
title('Transmit spectrogram');
subplot(2,1,2); imagesc(stftTime*1e3, f/1e3, rxStft); axis xy;
ylim([-130 130]); caxis([-45 0]); colorbar; xlabel('Time (ms)');
ylabel('Offset (kHz)'); title('Received spectrogram with partial-band jammer');
export_figure_pair(fig, cfg.figureRoot, 'spectrograms');

[txPsd, fp] = manual_psd(tx.waveform, cfg.sampleRateHz, 1024, 512, 4096);
[rxPsd, ~] = manual_psd(rxPacket, cfg.sampleRateHz, 1024, 512, 4096);
fig = figure('Visible','off','Color','w','Position',[100 100 900 440]);
plot(fp/1e3, txPsd, 'LineWidth',1.3); hold on;
plot(fp/1e3, rxPsd, 'LineWidth',1.0); hold off;
xlim([-150 150]); ylim([-70 5]); grid on;
xlabel('Frequency offset (kHz)'); ylabel('Normalized PSD (dB)');
legend('Transmit','Received','Location','best'); title('FHSS transmit and received spectra');
export_figure_pair(fig, cfg.figureRoot, 'transmit_receive_spectrum');

draw_system_diagram(cfg);
end

function draw_system_diagram(cfg)
fig = figure('Visible','off','Color','w','Position',[100 100 1200 520]);
axis off;
annotation(fig,'textbox',[.03 .70 .13 .12],'String','Payload + header', ...
    'HorizontalAlignment','center','VerticalAlignment','middle','LineWidth',1.2,'Color','k');
annotation(fig,'textbox',[.20 .70 .11 .12],'String','CRC + preamble', ...
    'HorizontalAlignment','center','VerticalAlignment','middle','LineWidth',1.2,'Color','k');
annotation(fig,'textbox',[.36 .70 .10 .12],'String','BPSK mapper', ...
    'HorizontalAlignment','center','VerticalAlignment','middle','LineWidth',1.2,'Color','k');
annotation(fig,'textbox',[.51 .70 .12 .12],'String','Frequency hopper', ...
    'HorizontalAlignment','center','VerticalAlignment','middle','LineWidth',1.2,'Color','k');
annotation(fig,'textbox',[.70 .70 .12 .12],'String','AWGN + partial-band jammer', ...
    'HorizontalAlignment','center','VerticalAlignment','middle','LineWidth',1.2,'Color','k');
annotation(fig,'textbox',[.43 .42 .12 .10],'String','Seeded hop generator', ...
    'HorizontalAlignment','center','VerticalAlignment','middle','LineWidth',1.2,'Color','k');
arrow(fig,[.16 .20],[.76 .76]); arrow(fig,[.31 .36],[.76 .76]);
arrow(fig,[.46 .51],[.76 .76]); arrow(fig,[.63 .70],[.76 .76]);
arrow(fig,[.49 .56],[.52 .70]);

annotation(fig,'textbox',[.84 .21 .12 .12],'String','Sync + dehopper', ...
    'HorizontalAlignment','center','VerticalAlignment','middle','LineWidth',1.2,'Color','k');
annotation(fig,'textbox',[.66 .21 .12 .12],'String','Integrate + BPSK decide', ...
    'HorizontalAlignment','center','VerticalAlignment','middle','LineWidth',1.2,'Color','k');
annotation(fig,'textbox',[.48 .21 .12 .12],'String','Frame sync + parse', ...
    'HorizontalAlignment','center','VerticalAlignment','middle','LineWidth',1.2,'Color','k');
annotation(fig,'textbox',[.30 .21 .12 .12],'String','CRC + BER/PER', ...
    'HorizontalAlignment','center','VerticalAlignment','middle','LineWidth',1.2,'Color','k');
arrow(fig,[.90 .90],[.70 .33]); arrow(fig,[.84 .78],[.27 .27]);
arrow(fig,[.66 .60],[.27 .27]); arrow(fig,[.48 .42],[.27 .27]);
annotation(fig,'textbox',[.14 .04 .72 .08], 'String', ...
    sprintf('Complex low-IF model: R_s = %.0f ksym/s, 8 channels, B_hop = %.0f kHz', ...
    cfg.symbolRateHz/1e3, cfg.totalHoppingBandwidthHz/1e3), ...
    'EdgeColor','none','HorizontalAlignment','center','FontWeight','bold','Color','k');
export_figure_pair(fig, cfg.figureRoot, 'tx_rx_block_diagram');
end

function arrow(fig, x, y)
annotation(fig,'arrow',x,y,'LineWidth',1.2,'Color','k');
end
