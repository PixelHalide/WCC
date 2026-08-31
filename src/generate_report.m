function generate_report(cfg, results)
%GENERATE_REPORT Populate the academic report template with measured results.

templatePath = fullfile('report','report_template.md');
outputPath = fullfile('report','report.md');
template = fileread(templatePath);
generated = results_markdown(cfg,results);
report = strrep(template,'{{GENERATED_RESULTS}}',generated);
fid = fopen(outputPath,'w');
if fid < 0
    error('fhss:ReportWrite','Could not open %s for writing.',outputPath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'%s',report);
clear cleanup;
end

function text = results_markdown(cfg,results)
p = results.performance;
baselineRate = cfg.symbolRateHz/cfg.symbolsPerHop;
rows = p(p.EbNoDb == 10 & p.HopRateHz == baselineRate, :);
rows = sortrows(rows,'Occupancy');

parts = cell(0,1);
parts{end+1} = sprintf(['The baseline at 10 dB used %.0f hops/s. Table 3 reports the ' ...
    'measured payload BER and PER as jammer occupancy increased.\n\n'],baselineRate);
parts{end+1} = sprintf('| Jammer occupancy | BER | 95%% BER interval | PER | 95%% PER interval |\n');
parts{end+1} = sprintf('|---:|---:|---:|---:|---:|\n');
for k = 1:height(rows)
    parts{end+1} = sprintf('| %.1f%% | %.4g | [%.4g, %.4g] | %.4g | [%.4g, %.4g] |\n', ...
        100*rows.Occupancy(k),rows.BER(k),rows.BERLow(k),rows.BERHigh(k), ...
        rows.PER(k),rows.PERLow(k),rows.PERHigh(k));
end

parts{end+1} = sprintf(['\nThe selection rule recommends an eight-channel hop set at **%.0f ' ...
    'hops/s**. Eight is the largest orthogonal set supported by the specified ' ...
    '195 kHz band and 25 kHz spacing. When rate candidates had overlapping ' ...
    '95%% intervals, the rule selected the slower rate to reduce switching and ' ...
    'synchronization complexity.\n\n'],results.recommendation.hopRateHz);

fixed = results.fixed(results.fixed.EbNoDb == 10,:);
parts{end+1} = sprintf('Table 4 compares FHSS with fixed-frequency alternatives at equal average transmit power.\n\n');
parts{end+1} = sprintf('| Link | BER | PER | Packets |\n|:--|--:|--:|--:|\n');
for k = 1:height(fixed)
    parts{end+1} = sprintf('| %s | %.4g | %.4g | %d |\n', ...
        strrep(fixed.LinkType{k},'_',' '),fixed.BER(k),fixed.PER(k),fixed.Packets(k));
end

offset = results.mismatch(strcmp(results.mismatch.Study,'One-hop offset'),:);
acquired = results.mismatch(strcmp(results.mismatch.Study,'Acquired'),:);
parts{end+1} = sprintf('\nTable 5 contrasts forced one-hop misalignment with preamble-assisted acquisition.\n\n');
parts{end+1} = sprintf('| Hop rate | Forced-offset BER | Forced-offset PER | Acquired sync probability |\n|---:|---:|---:|---:|\n');
for k = 1:height(offset)
    match = acquired(acquired.HopRateHz == offset.HopRateHz(k),:);
    parts{end+1} = sprintf('| %.0f hops/s | %.4g | %.4g | %.3f |\n', ...
        offset.HopRateHz(k),offset.BER(k),offset.PER(k),match.SyncProbability(1));
end

overlapCount = sum(results.crosscheck.IntervalsOverlap);
parts{end+1} = sprintf(['\nThe symbol-domain and full-waveform BER confidence intervals overlapped ' ...
    'in %d of %d validation cases. The jammer cases reveal the expected effect ' ...
    'of asynchronous jammer symbol boundaries and adjacent-channel leakage. ' ...
    'Accordingly, the main BER/PER grid, synchronization, and rate-mismatch ' ...
    'results use the full sample-domain waveform; the symbol model is retained ' ...
    'only for the fixed-link decision-level comparison.\n'],overlapCount,height(results.crosscheck));
text = [parts{:}];
end
