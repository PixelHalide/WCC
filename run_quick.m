function demo = run_quick()
%RUN_QUICK Run deterministic tests and one baseline packet without Monte Carlo.
projectRoot = fileparts(mfilename('fullpath'));
originalFolder = pwd;
cleanup = onCleanup(@() cd(originalFolder));
cd(projectRoot);
addpath(fullfile(projectRoot,'src'));
addpath(fullfile(projectRoot,'tests'));
cfg = fhss_config();
run_tests();
demo = simulate_packet(cfg,struct('frameId',1,'ebNoDb',10, ...
    'jammerOccupancy',0.25,'acquire',true),'waveform');
fprintf('BER %.4g, CRC %d, synchronization %d, metric %.3f\n', ...
    demo.ber,demo.crcOk,demo.syncSuccess,demo.receiver.sync.metric);
clear cleanup;
end
