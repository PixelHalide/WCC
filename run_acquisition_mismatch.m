function results = run_acquisition_mismatch(packetsPerPoint)
%RUN_ACQUISITION_MISMATCH Repeat the mismatch grid with timing acquisition.
% Uses the original mismatch study's seeds for paired packet comparisons.
if nargin < 1, packetsPerPoint = 50; end
validateattributes(packetsPerPoint, {'numeric'}, {'scalar','integer','positive'});
projectRoot = fileparts(mfilename('fullpath'));
originalFolder = pwd;
cleanup = onCleanup(@() cd(originalFolder));
cd(projectRoot);
addpath(genpath(fullfile(projectRoot,'src')));
cfg = fhss_config();
if ~exist(cfg.outputRoot,'dir'), mkdir(cfg.outputRoot); end
rows = cell(0,10);
condition = 1000;
for symbolsPerHop = cfg.experiment.symbolsPerHop
    for rateError = cfg.experiment.mismatchRateErrors
        condition = condition + 1;
        bitErrors = 0; packetErrors = 0; syncSuccesses = 0;
        for packet = 1:packetsPerPoint
            seedOffset = condition*100000 + packet;
            scenario = struct('symbolsPerHop',symbolsPerHop, ...
                'jammerOccupancy',0.25,'ebNoDb',10,'rateError',rateError, ...
                'codeOffset',0,'acquire',true,'frameId',mod(seedOffset,65536), ...
                'noiseSeed',cfg.seeds.noise+seedOffset, ...
                'jammerSeed',cfg.seeds.jammer+seedOffset, ...
                'timingSeed',cfg.seeds.timing+seedOffset, ...
                'hopSeed',cfg.seeds.hop+seedOffset);
            out = simulate_packet(cfg,scenario,'waveform');
            bitErrors = bitErrors + out.bitErrors;
            packetErrors = packetErrors + double(out.packetError);
            syncSuccesses = syncSuccesses + double(out.syncSuccess);
        end
        ci = wilson_interval(syncSuccesses,packetsPerPoint);
        rows(end+1,:) = {symbolsPerHop,cfg.symbolRateHz/symbolsPerHop, ...
            100*rateError,packetsPerPoint,bitErrors, ...
            bitErrors/(packetsPerPoint*cfg.payloadBits), ...
            packetErrors/packetsPerPoint,syncSuccesses/packetsPerPoint,ci(1),ci(2)}; %#ok<AGROW>
        results = cell2table(rows,'VariableNames',{'SymbolsPerHop','HopRateHz', ...
            'RateErrorPercent','Packets','BitErrors','BER','PER', ...
            'SyncProbability','SyncLow','SyncHigh'});
        writetable(results,fullfile(cfg.outputRoot,'acquisition_mismatch.csv'));
        fprintf('%g hops/s, error %+.2f%%: sync %d/%d, BER %.4g, PER %.3f\n', ...
            cfg.symbolRateHz/symbolsPerHop,100*rateError,syncSuccesses, ...
            packetsPerPoint,results.BER(end),results.PER(end));
    end
    % Original study inserts one-offset and zero-mismatch acquisition cases.
    condition = condition + 2;
end
save(fullfile(cfg.outputRoot,'acquisition_mismatch.mat'),'results','cfg','-v7');
fig = figure('Visible','off','Color','w','Position',[100 100 1400 460]);
fields = {'BER','PER','SyncProbability'};
titles = {'Payload BER','Packet error rate','Frame synchronization'};
rates = unique(results.HopRateHz);
for panel = 1:3
    subplot(1,3,panel); hold on;
    for rate = rates.'
        selected = results(results.HopRateHz == rate,:);
        plot(selected.RateErrorPercent,selected.(fields{panel}),'-o','LineWidth',1.3);
    end
    grid on; xlabel('Receiver hop dwell-time error (%)');
    ylabel(fields{panel}); title(titles{panel});
    if panel > 1, ylim([0 1.05]); end
end
legend(arrayfun(@(r) sprintf('%g hops/s',r),rates,'UniformOutput',false), ...
    'Location','best');
sgtitle(sprintf(['Acquisition enabled: %d packets/point, E_b/N_0 = 10 dB, ' ...
    'occupancy = 25%%, J/S = %g dB'],packetsPerPoint,cfg.defaultJsDb),'Color','k');
export_figure_pair(fig,cfg.figureRoot,'acquisition_hop_rate_mismatch');
clear cleanup;
end
