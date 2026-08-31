function plot_results(cfg, results)
%PLOT_RESULTS Export BER/PER, mismatch, and fixed-link comparison curves.
performance = results.performance;
occupancies = unique(performance.Occupancy).';
rates = unique(performance.HopRateHz).';
colors = lines(numel(occupancies));

fig = figure('Visible','off','Color','w','Position',[100 100 1200 440]);
for r = 1:numel(rates)
    subplot(1,numel(rates),r); hold on;
    for o = 1:numel(occupancies)
        rows = performance(performance.HopRateHz == rates(r) & ...
            performance.Occupancy == occupancies(o), :);
        semilogy(rows.EbNoDb, max(rows.BER, 0.5./rows.PayloadBits), '-o', ...
            'Color',colors(o,:),'LineWidth',1.1,'MarkerSize',4);
    end
    theory = 0.5*erfc(sqrt(10.^(cfg.experiment.ebNoDb/10)));
    semilogy(cfg.experiment.ebNoDb, theory, 'k--','LineWidth',1.0);
    set(gca,'YScale','log'); grid on; ylim([1e-5 1]); xlabel('E_b/N_0 (dB)');
    if r == 1, ylabel('Payload BER'); end
    title(sprintf('%.0f hops/s',rates(r)));
end
legend([arrayfun(@(x) sprintf('Occupancy %.1f%%',100*x),occupancies,'UniformOutput',false), ...
    {'BPSK theory'}], 'Location','southoutside');
export_figure_pair(fig, cfg.figureRoot, 'ber_occupancy_hoprate');

fig = figure('Visible','off','Color','w','Position',[100 100 1200 440]);
for r = 1:numel(rates)
    subplot(1,numel(rates),r); hold on;
    for o = 1:numel(occupancies)
        rows = performance(performance.HopRateHz == rates(r) & ...
            performance.Occupancy == occupancies(o), :);
        semilogy(rows.EbNoDb, max(rows.PER, 0.5./rows.Packets), '-o', ...
            'Color',colors(o,:),'LineWidth',1.1,'MarkerSize',4);
    end
    set(gca,'YScale','log'); grid on; ylim([1e-3 1]); xlabel('E_b/N_0 (dB)');
    if r == 1, ylabel('Packet error rate'); end
    title(sprintf('%.0f hops/s',rates(r)));
end
legend(arrayfun(@(x) sprintf('Occupancy %.1f%%',100*x),occupancies,'UniformOutput',false), ...
    'Location','southoutside');
export_figure_pair(fig, cfg.figureRoot, 'per_occupancy_hoprate');

mismatch = results.mismatch(strcmp(results.mismatch.Study,'Rate mismatch'),:);
fig = figure('Visible','off','Color','w','Position',[100 100 1200 440]);
subplot(1,3,1); hold on;
for r = 1:numel(rates)
    rows = mismatch(mismatch.HopRateHz == rates(r),:);
    plot(rows.RateErrorPercent, rows.BER, '-o','LineWidth',1.2);
end
grid on; xlabel('Rate error (%)'); ylabel('BER'); ylim([0 0.45]); title('Payload BER');
subplot(1,3,2); hold on;
for r = 1:numel(rates)
    rows = mismatch(mismatch.HopRateHz == rates(r),:);
    plot(rows.RateErrorPercent, rows.PER, '-o','LineWidth',1.2);
end
grid on; xlabel('Rate error (%)'); ylabel('PER'); ylim([0 1.05]); title('Packet error rate');
subplot(1,3,3); hold on;
for r = 1:numel(rates)
    rows = mismatch(mismatch.HopRateHz == rates(r),:);
    plot(rows.RateErrorPercent, rows.SyncProbability, '-o','LineWidth',1.2);
end
grid on; xlabel('Rate error (%)'); ylabel('Probability'); ylim([0 1.05]);
title('Frame synchronization');
legend(arrayfun(@(x) sprintf('%.0f hops/s',x),rates,'UniformOutput',false), ...
    'Location','best');
export_figure_pair(fig, cfg.figureRoot, 'hop_rate_mismatch');

fixed = results.fixed;
types = unique(fixed.LinkType,'stable');
fig = figure('Visible','off','Color','w','Position',[100 100 900 440]); hold on;
for k = 1:numel(types)
    rows = fixed(strcmp(fixed.LinkType,types{k}),:);
    semilogy(rows.EbNoDb, max(rows.BER,0.5./rows.PayloadBits),'-o','LineWidth',1.2);
end
set(gca,'YScale','log'); grid on; ylim([1e-5 1]); xlabel('E_b/N_0 (dB)'); ylabel('Payload BER');
legend(strrep(types,'_',' '),'Location','best');
title('FHSS and fixed-frequency comparison at equal average power');
export_figure_pair(fig, cfg.figureRoot, 'fhss_fixed_comparison');
end
