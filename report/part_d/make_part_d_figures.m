function make_part_d_figures()
%MAKE_PART_D_FIGURES Plot the archived run used in the handwritten Part B.
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root,'..','..','src'));
p = readtable(fullfile(root,'data','performance.csv'));
m = readtable(fullfile(root,'data','mismatch.csv'));
f = readtable(fullfile(root,'data','fixed_comparison.csv'));
out = fullfile(root,'figures');
if ~exist(out,'dir'), mkdir(out); end

fig = figure('Visible','off','Position',[100 100 850 430]);
hold on;
occupancies = [0 .125 .25 .5];
for occupancy = occupancies
    t = p(p.HopRateHz==1250 & p.Occupancy==occupancy,:);
    plot(t.EbNoDb,max(t.BER,0.5./t.PayloadBits),'-o','LineWidth',1.5);
end
set(gca,'YScale','log'); ylim([1e-6 1]); xlim([0 14]); xticks(0:2:14);
grid on; xlabel('E_b/N_0 (dB)'); ylabel('Payload BER');
legend('No jammer','12.5% occupancy','25% occupancy','50% occupancy','Location','southwest');
title('Jammer occupancy: 1,250 hops/s, aggregate J/S = 10 dB');
export_figure_pair(fig,out,'D1_occupancy');

fig = figure('Visible','off','Position',[100 100 850 430]); hold on;
for rate = [625 1250 2500]
    t = m(strcmp(m.Study,'Rate mismatch') & m.HopRateHz==rate,:);
    plot(t.RateErrorPercent,t.BER,'-o','LineWidth',1.5);
end
grid on; xlim([-2 2]); ylim([0 .4]); xticks([-2 -1 -.5 0 .5 1 2]);
xlabel('Receiver dwell-duration error (%)'); ylabel('Payload BER');
legend('625 hops/s','1,250 hops/s','2,500 hops/s','Location','north');
title('Hop mismatch: E_b/N_0 = 10 dB, occupancy = 25%, J/S = 10 dB');
export_figure_pair(fig,out,'D2_mismatch');

fig = figure('Visible','off','Position',[100 100 850 430]); hold on;
types = {'fhss','fixed_jammed','fixed_clean','fixed_random'};
for k = 1:numel(types)
    t = f(strcmp(f.LinkType,types{k}),:);
    plot(t.EbNoDb,max(t.BER,0.5./t.PayloadBits),'-o','LineWidth',1.5);
end
set(gca,'YScale','log'); ylim([1e-6 1]); xlim([0 14]); xticks(0:2:14]);
grid on; xlabel('E_b/N_0 (dB)'); ylabel('Payload BER');
legend('FHSS','Fixed jammed','Fixed clean','Fixed random','Location','southwest');
title('Equal-power BPSK comparison: idealized symbol model, 25% occupancy');
export_figure_pair(fig,out,'D3_fixed_link');
end
