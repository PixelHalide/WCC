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

parts{end+1} = sprintf(['\nThe provisional engineering recommendation is an eight-channel ' ...
    'hop set at **%.0f hops/s**, corresponding to **%.2f ms per hop**. The eight ' ...
    'configured channels occupy a nominal 195 kHz span with 25 kHz spacing. ' ...
    'The rate selection considers acquired packet errors as well as known-timing ' ...
    'performance; preamble recognition alone does not establish correct hop alignment. ' ...
    'Larger acquisition-enabled trials are needed to confirm the choice.\n\n'], ...
    results.recommendation.hopRateHz,1e3/results.recommendation.hopRateHz);

fixed = results.fixed(results.fixed.EbNoDb == 10,:);
parts{end+1} = sprintf('Table 4 compares FHSS with fixed-frequency alternatives at equal average transmit power.\n\n');
parts{end+1} = sprintf('| Link | BER | PER | Packets |\n|:--|--:|--:|--:|\n');
for k = 1:height(fixed)
    parts{end+1} = sprintf('| %s | %.4g | %.4g | %d |\n', ...
        strrep(fixed.LinkType{k},'_',' '),fixed.BER(k),fixed.PER(k),fixed.Packets(k));
end

rateStudy = results.mismatch(strcmp(results.mismatch.Study,'Rate mismatch'),:);
parts{end+1} = sprintf('\nThe hop-chip-time mismatch BER/PER study uses 200 packets per point with acquisition disabled and supplied timing and initial code phase. The frame-synchronization panel uses a separate acquisition-enabled sweep with 50 packets per point.\n\n');
parts{end+1} = sprintf('| Hop rate | Hop chip time error | Packet errors / packets | PER |\n|---:|---:|---:|---:|\n');
for rate = unique(rateStudy.HopRateHz).'
    for errorPercent = [-0.1 0 0.1]
        row = rateStudy(rateStudy.HopRateHz == rate & abs(rateStudy.RateErrorPercent-errorPercent) < 1e-9,:);
        if ~isempty(row)
            parts{end+1} = sprintf('| %.0f hops/s | %+.1f%% | %d / %d | %.3f |\n', ...
                rate, errorPercent, row.PacketErrors(1), row.Packets(1), row.PER(1));
        end
    end
end

offset = results.mismatch(strcmp(results.mismatch.Study,'One-hop offset'),:);
acquired = results.mismatch(strcmp(results.mismatch.Study,'Acquired'),:);
parts{end+1} = sprintf('\nTable 5 contrasts forced one-hop misalignment with preamble-assisted acquisition.\n\n');
parts{end+1} = sprintf('| Hop rate | Offset BER | Offset PER | Acquired sync | Acquired PER |\n|---:|---:|---:|---:|---:|\n');
for k = 1:height(offset)
    match = acquired(acquired.HopRateHz == offset.HopRateHz(k),:);
    parts{end+1} = sprintf('| %.0f hops/s | %.4g | %.4g | %.3f | %.3f |\n', ...
        offset.HopRateHz(k),offset.BER(k),offset.PER(k),match.SyncProbability(1),match.PER(1));
end
parts{end+1} = sprintf(['\nThe acquisition columns use 50 packets per rate in a separate ' ...
    'zero-mismatch experiment; the forced-offset columns use 200 packets per rate. ' ...
    'Acquired synchronization records passing the preamble checks and can accept a ' ...
    'wrong hopping-code phase. Acquired PER includes CRC failures and therefore exposes ' ...
    'payload failures hidden by that synchronization metric.\n']);

overlapCount = sum(results.crosscheck.IntervalsOverlap);
parts{end+1} = sprintf(['\nThe symbol-domain and full-waveform BER confidence intervals overlapped ' ...
    'in %d of %d validation cases. The jammer cases reveal the expected effect ' ...
    'of asynchronous jammer symbol boundaries and adjacent-channel leakage. ' ...
    'Accordingly, the main BER/PER grid, mismatch, and synchronization ' ...
    'results use the full sample-domain waveform; the symbol model is retained ' ...
    'only for the fixed-link decision-level comparison.\n'],overlapCount,height(results.crosscheck));
text = [parts{:}];
end
