function results = run_all()
%RUN_ALL Verify the FHSS project and regenerate all evidence and report data.

projectRoot = fileparts(mfilename('fullpath'));
originalFolder = pwd;
cleanup = onCleanup(@() cd(originalFolder));
cd(projectRoot);
addpath(fullfile(projectRoot,'src'));
addpath(fullfile(projectRoot,'tests'));
cfg = fhss_config();
if ~exist(cfg.outputRoot,'dir'), mkdir(cfg.outputRoot); end
if ~exist(cfg.figureRoot,'dir'), mkdir(cfg.figureRoot); end

fprintf('FHSS project: deterministic verification\n');
testSummary = run_tests();
writetable(testSummary,fullfile(cfg.outputRoot,'test_summary.csv'));

fprintf('FHSS project: baseline waveform evidence\n');
demoScenario = struct('frameId',1,'symbolsPerHop',8,'ebNoDb',10, ...
    'jammerOccupancy',0.25,'jsDb',10,'acquire',true);
demo = simulate_packet(cfg,demoScenario,'waveform');
assert(demo.receiver.sync.metric >= cfg.syncMetricThreshold, ...
    'Baseline demonstration did not meet the synchronization metric threshold.');
save(fullfile(cfg.outputRoot,'baseline_demo.mat'),'demo','-v7');
plot_demo(cfg,demo);

fprintf('FHSS project: Monte Carlo experiments\n');
results = run_experiments(cfg);
results.testSummary = testSummary;
save(fullfile(cfg.outputRoot,'results.mat'),'results','-v7');
plot_results(cfg,results);
generate_report(cfg,results);

fprintf('\nComplete. Build the PDF with:\n');
fprintf('  pandoc report/report.md -o report/FHSS_Project_Report.pdf --pdf-engine=xelatex\n');
clear cleanup;
end
