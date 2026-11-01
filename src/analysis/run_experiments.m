function results = run_experiments(cfg)
%RUN_EXPERIMENTS Execute the complete reproducible project experiment set.

if nargin < 1
    cfg = fhss_config();
end
ensure_output_dirs(cfg);
fprintf('Running BER/PER occupancy and hop-rate grid...\n');
performance = run_performance_grid(cfg);
fprintf('Running hop synchronization and mismatch study...\n');
mismatch = run_mismatch_study(cfg);
fprintf('Running fixed-frequency comparison...\n');
fixed = run_fixed_comparison(cfg);
fprintf('Cross-checking waveform and symbol models...\n');
crosscheck = run_crosscheck(cfg);
recommendation = choose_recommendation(performance, mismatch);
results = struct('performance', performance, 'mismatch', mismatch, ...
    'fixed', fixed, 'crosscheck', crosscheck, ...
    'recommendation', recommendation, 'config', cfg);
save(fullfile(cfg.outputRoot, 'results.mat'), 'results', '-v7');
writetable(performance, fullfile(cfg.outputRoot, 'performance.csv'));
writetable(mismatch, fullfile(cfg.outputRoot, 'mismatch.csv'));
writetable(fixed, fullfile(cfg.outputRoot, 'fixed_comparison.csv'));
writetable(crosscheck, fullfile(cfg.outputRoot, 'model_crosscheck.csv'));
end

function performance = run_performance_grid(cfg)
rows = cell(0, 17);
condition = 0;
for symbolsPerHop = cfg.experiment.symbolsPerHop
    for occupancy = cfg.experiment.occupancies
        for ebNoDb = cfg.experiment.ebNoDb
            condition = condition + 1;
            stats = monte_carlo(cfg, struct('symbolsPerHop', symbolsPerHop, ...
                'jammerOccupancy', occupancy, 'ebNoDb', ebNoDb, ...
                'linkType', 'fhss', 'acquire', false), 'waveform', condition, ...
                cfg.experiment.minPackets, cfg.experiment.maxPackets, ...
                cfg.experiment.stopPacketErrors);
            berCI = wilson_interval(stats.bitErrors, stats.bits);
            perCI = wilson_interval(stats.packetErrors, stats.packets);
            rows(end+1,:) = {symbolsPerHop, dwell_ms(cfg, symbolsPerHop), ...
                hop_rate(cfg, symbolsPerHop), occupancy, ebNoDb, cfg.defaultJsDb, ...
                stats.packets, stats.bits, stats.bitErrors, stats.ber, ...
                berCI(1), berCI(2), stats.packetErrors, stats.per, ...
                perCI(1), perCI(2), 1-stats.syncFailures/stats.packets}; %#ok<AGROW>
        end
    end
end
names = {'SymbolsPerHop','DwellMs','HopRateHz','Occupancy','EbNoDb','JsDb', ...
    'Packets','PayloadBits','BitErrors','BER','BERLow','BERHigh', ...
    'PacketErrors','PER','PERLow','PERHigh','SyncProbability'};
performance = cell2table(rows, 'VariableNames', names);
end

function mismatch = run_mismatch_study(cfg)
rows = cell(0, 16);
condition = 1000;
for symbolsPerHop = cfg.experiment.symbolsPerHop
    for rateError = cfg.experiment.mismatchRateErrors
        condition = condition + 1;
        stats = monte_carlo(cfg, struct('symbolsPerHop', symbolsPerHop, ...
            'jammerOccupancy', 0.25, 'ebNoDb', 10, 'rateError', rateError, ...
            'codeOffset', 0, 'acquire', false), 'waveform', condition, ...
            cfg.experiment.mismatchPackets, cfg.experiment.mismatchPackets, Inf);
        rows(end+1,:) = mismatch_row(cfg, 'Rate mismatch', symbolsPerHop, ...
            rateError, 0, false, stats); %#ok<AGROW>
    end
    condition = condition + 1;
    stats = monte_carlo(cfg, struct('symbolsPerHop', symbolsPerHop, ...
        'jammerOccupancy', 0.25, 'ebNoDb', 10, 'rateError', 0, ...
        'codeOffset', 1, 'acquire', false), 'waveform', condition, ...
        cfg.experiment.mismatchPackets, cfg.experiment.mismatchPackets, Inf);
    rows(end+1,:) = mismatch_row(cfg, 'One-hop offset', symbolsPerHop, ...
        0, 1, false, stats); %#ok<AGROW>

    condition = condition + 1;
    stats = monte_carlo(cfg, struct('symbolsPerHop', symbolsPerHop, ...
        'jammerOccupancy', 0.25, 'ebNoDb', 10, 'rateError', 0, ...
        'codeOffset', 0, 'acquire', true), 'waveform', condition, ...
        cfg.experiment.syncPackets, cfg.experiment.syncPackets, Inf);
    rows(end+1,:) = mismatch_row(cfg, 'Acquired', symbolsPerHop, ...
        0, 0, true, stats); %#ok<AGROW>
end
names = {'Study','SymbolsPerHop','HopRateHz','RateErrorPercent','CodeOffset', ...
    'AcquisitionEnabled','Packets','PayloadBits','BitErrors','BER','BERLow', ...
    'BERHigh','PacketErrors','PER','SyncProbability','SyncFailureRate'};
mismatch = cell2table(rows, 'VariableNames', names);
end

function row = mismatch_row(cfg, label, symbolsPerHop, rateError, codeOffset, acquired, stats)
berCI = wilson_interval(stats.bitErrors, stats.bits);
row = {label, symbolsPerHop, hop_rate(cfg, symbolsPerHop), 100*rateError, ...
    codeOffset, acquired, stats.packets, stats.bits, stats.bitErrors, stats.ber, ...
    berCI(1), berCI(2), stats.packetErrors, stats.per, ...
    1-stats.syncFailures/stats.packets, stats.syncFailures/stats.packets};
end

function fixed = run_fixed_comparison(cfg)
types = {'fhss','fixed_jammed','fixed_clean','fixed_random'};
rows = cell(0, 12);
condition = 2000;
for typeIndex = 1:numel(types)
    for ebNoDb = cfg.experiment.ebNoDb
        condition = condition + 1;
        stats = monte_carlo(cfg, struct('symbolsPerHop', 8, ...
            'jammerOccupancy', 0.25, 'ebNoDb', ebNoDb, ...
            'linkType', types{typeIndex}, 'acquire', false), 'symbol', condition, ...
            cfg.experiment.minPackets, cfg.experiment.maxPackets, ...
            cfg.experiment.stopPacketErrors);
        berCI = wilson_interval(stats.bitErrors, stats.bits);
        perCI = wilson_interval(stats.packetErrors, stats.packets);
        rows(end+1,:) = {types{typeIndex}, ebNoDb, stats.packets, stats.bits, ...
            stats.bitErrors, stats.ber, berCI(1), berCI(2), ...
            stats.packetErrors, stats.per, perCI(1), perCI(2)}; %#ok<AGROW>
    end
end
names = {'LinkType','EbNoDb','Packets','PayloadBits','BitErrors','BER', ...
    'BERLow','BERHigh','PacketErrors','PER','PERLow','PERHigh'};
fixed = cell2table(rows, 'VariableNames', names);
end

function crosscheck = run_crosscheck(cfg)
conditions = [6 0; 10 0.25; 14 0.50];
rows = cell(0, 9);
for k = 1:size(conditions,1)
    ebNo = conditions(k,1);
    occupancy = conditions(k,2);
    symbolStats = monte_carlo(cfg, struct('ebNoDb', ebNo, ...
        'jammerOccupancy', occupancy, 'symbolsPerHop', 8, 'acquire', false), ...
        'symbol', 3000+k, 100, 100, Inf);
    waveformStats = monte_carlo(cfg, struct('ebNoDb', ebNo, ...
        'jammerOccupancy', occupancy, 'symbolsPerHop', 8, 'acquire', false), ...
        'waveform', 4000+k, 100, 100, Inf);
    sCI = wilson_interval(symbolStats.bitErrors, symbolStats.bits);
    wCI = wilson_interval(waveformStats.bitErrors, waveformStats.bits);
    overlap = max(sCI(1),wCI(1)) <= min(sCI(2),wCI(2));
    rows(end+1,:) = {ebNo, occupancy, symbolStats.ber, sCI(1), sCI(2), ...
        waveformStats.ber, wCI(1), wCI(2), overlap}; %#ok<AGROW>
end
crosscheck = cell2table(rows, 'VariableNames', {'EbNoDb','Occupancy', ...
    'SymbolBER','SymbolLow','SymbolHigh','WaveformBER','WaveformLow', ...
    'WaveformHigh','IntervalsOverlap'});
end

function stats = monte_carlo(cfg, scenarioBase, mode, condition, minPackets, maxPackets, stopErrors)
stats = struct('packets', 0, 'bits', 0, 'bitErrors', 0, ...
    'packetErrors', 0, 'syncFailures', 0, 'ber', NaN, 'per', NaN);
while stats.packets < maxPackets
    packet = stats.packets + 1;
    seedOffset = condition*100000 + packet;
    scenario = scenarioBase;
    scenario.frameId = mod(seedOffset, 65536);
    scenario.noiseSeed = cfg.seeds.noise + seedOffset;
    scenario.jammerSeed = cfg.seeds.jammer + seedOffset;
    scenario.timingSeed = cfg.seeds.timing + seedOffset;
    scenario.hopSeed = cfg.seeds.hop + seedOffset;
    out = simulate_packet(cfg, scenario, mode);
    stats.packets = packet;
    stats.bits = stats.bits + cfg.payloadBits;
    stats.bitErrors = stats.bitErrors + out.bitErrors;
    stats.packetErrors = stats.packetErrors + double(out.packetError);
    stats.syncFailures = stats.syncFailures + double(~out.syncSuccess);
    if packet >= minPackets && stats.packetErrors >= stopErrors
        break;
    end
end
stats.ber = stats.bitErrors/stats.bits;
stats.per = stats.packetErrors/stats.packets;
end

function recommendation = choose_recommendation(performance, mismatch)
target = performance(performance.EbNoDb == 10 & performance.Occupancy == 0.25, :);
% Use actual acquisition trials, not preamble detection with known timing.
acquired = mismatch(strcmp(mismatch.Study, 'Acquired'), :);
bestSync = max(acquired.SyncProbability);
eligibleRates = acquired.HopRateHz(acquired.SyncProbability >= bestSync - 0.05);
eligible = target(ismember(target.HopRateHz, eligibleRates), :);
rates = unique(eligible.HopRateHz);
summary = zeros(numel(rates), 4);
for k = 1:numel(rates)
    rows = eligible(eligible.HopRateHz == rates(k), :);
    summary(k,:) = [rates(k), mean(rows.PER), mean(rows.PERLow), mean(rows.PERHigh)];
end
[~, bestIndex] = min(summary(:,2));
best = summary(bestIndex,:);
overlapping = summary(:,3) <= best(4) & summary(:,4) >= best(3);
selectedRate = min(summary(overlapping,1));
recommendation = struct('hopSetSize', 8, 'hopRateHz', selectedRate, ...
    'rule', ['Largest orthogonal hop set; minimum mean PER among rates within ' ...
    'five percentage points of best synchronization, choosing the slower ' ...
    'rate when 95% confidence intervals overlap.']);
end

function value = dwell_ms(cfg, symbolsPerHop)
value = 1e3 * symbolsPerHop / cfg.symbolRateHz;
end

function value = hop_rate(cfg, symbolsPerHop)
value = cfg.symbolRateHz / symbolsPerHop;
end

function ensure_output_dirs(cfg)
if ~exist(cfg.outputRoot, 'dir'), mkdir(cfg.outputRoot); end
if ~exist(cfg.figureRoot, 'dir'), mkdir(cfg.figureRoot); end
end
