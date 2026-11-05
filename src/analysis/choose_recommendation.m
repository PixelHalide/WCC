function recommendation = choose_recommendation(performance, mismatch)
%CHOOSE_RECOMMENDATION Provisional choice using acquired packet reliability.
target = performance(performance.EbNoDb == 10 & performance.Occupancy == 0.25,:);
acquired = mismatch(strcmp(mismatch.Study,'Acquired'),:);
% Preamble success alone can accept an incorrect hopping-code alignment.
% This five-percentage-point tolerance is an engineering screening heuristic,
% not a statistical equivalence test on the small acquisition sample.
bestAcquiredPER = min(acquired.PER);
eligibleRates = acquired.HopRateHz(acquired.PER <= bestAcquiredPER + 0.05);
eligible = target(ismember(target.HopRateHz,eligibleRates),:);
if isempty(eligible)
    error('fhss:RecommendationData','No eligible target operating points.');
end
eligible = sortrows(eligible,{'PER','HopRateHz'});
recommendation = struct('hopSetSize',8,'hopRateHz',eligible.HopRateHz(1), ...
    'provisional',true, ...
    'rule',['Retain rates whose acquired PER is within five percentage points ' ...
    'of the best observed value; choose the lowest known-timing PER at 10 dB ' ...
    'and 25% occupancy. Confirm with larger acquisition-enabled trials.']);
end
