function summary = run_tests()
%RUN_TESTS Deterministic verification suite for the FHSS project.

cfg = fhss_config();
tests = {@test_crc, @test_frame, @test_hops, @test_noiseless_links, ...
    @test_awgn_ber, @test_sync_acquisition, @test_misalignment, ...
    @test_fixed_equivalence, @test_base_matlab_dependencies};
names = {'CRC-16 reference vector','Frame construction','Balanced hopping', ...
    'Noiseless end-to-end links','AWGN BPSK theory','Hop acquisition', ...
    'Deliberate misalignment','FHSS/fixed no-jammer equivalence', ...
    'Base-MATLAB dependency scan'};
passed = false(size(tests));
messages = cell(size(tests));
for k = 1:numel(tests)
    try
        tests{k}(cfg);
        passed(k) = true;
        messages{k} = 'PASS';
        fprintf('[PASS] %s\n', names{k});
    catch exception
        messages{k} = exception.message;
        fprintf('[FAIL] %s: %s\n', names{k}, exception.message);
    end
end
summary = table(names(:), passed(:), messages(:), ...
    'VariableNames', {'Test','Passed','Message'});
if ~all(passed)
    error('fhss:TestsFailed', '%d of %d project tests failed.', sum(~passed), numel(passed));
end
end

function test_crc(~)
bits = bytes_to_bits(uint8('123456789'));
actual = crc16_ccitt(bits);
assert(actual == uint16(hex2dec('29B1')), 'Expected CRC 0x29B1, got 0x%04X.', actual);
end

function test_frame(cfg)
frame = build_frame(cfg, 42, zeros(1,cfg.payloadBits));
assert(numel(frame.bits) == 320);
assert(isequal(frame.bits(1:32), cfg.preambleBits));
assert(bits_to_uint(frame.header) == uint32(42));
assert(crc16_ccitt([frame.header frame.payload]) == frame.crcValue);
end

function test_hops(cfg)
a = hop_sequence(cfg, 32, cfg.hopStartIndex);
b = hop_sequence(cfg, 32, cfg.hopStartIndex);
assert(isequal(a,b), 'Tx/Rx hop generation is not reproducible.');
assert(all(a >= 1 & a <= 8), 'Hop channel is outside 1..8.');
for first = 1:8:numel(a)
    assert(isequal(sort(a(first:first+7)),1:8), ...
        'A permutation block does not visit all channels exactly once.');
end
end

function test_noiseless_links(cfg)
for symbolsPerHop = [16 8 4]
    scenario = struct('symbolsPerHop',symbolsPerHop,'ebNoDb',Inf, ...
        'jammerOccupancy',0,'jsDb',Inf,'acquire',false, ...
        'timingOffsetSamples',0,'frameId',symbolsPerHop);
    out = simulate_packet(cfg,scenario,'waveform');
    assert(out.bitErrors == 0 && out.crcOk && out.syncSuccess, ...
        'Noiseless link failed at %d symbols/hop.',symbolsPerHop);
end
end

function test_awgn_ber(cfg)
ebNoDb = 6;
errors = 0;
bits = 0;
for packet = 1:400
    scenario = struct('frameId',packet,'symbolsPerHop',8,'ebNoDb',ebNoDb, ...
        'jammerOccupancy',0,'acquire',false, ...
        'noiseSeed',cfg.seeds.noise+packet);
    out = simulate_packet(cfg,scenario,'symbol');
    errors = errors + out.bitErrors;
    bits = bits + cfg.payloadBits;
end
measured = errors/bits;
theory = 0.5*erfc(sqrt(10^(ebNoDb/10)));
sigma = sqrt(max(theory*(1-theory)/bits,eps));
assert(abs(measured-theory) <= 5*sigma + 5e-4, ...
    'Measured BER %.4g does not agree with theory %.4g.',measured,theory);
end

function test_sync_acquisition(cfg)
successes = 0;
trials = 20;
for packet = 1:trials
    scenario = struct('frameId',packet,'symbolsPerHop',8,'ebNoDb',14, ...
        'jammerOccupancy',0,'acquire',true, ...
        'noiseSeed',cfg.seeds.noise+packet, ...
        'timingSeed',cfg.seeds.timing+packet);
    out = simulate_packet(cfg,scenario,'waveform');
    successes = successes + double(out.syncSuccess && ...
        out.receiver.sync.codeOffset == 0 && ...
        out.receiver.sync.timingOffsetSamples == out.channel.timingOffsetSamples);
end
assert(successes == trials, 'Acquisition succeeded in %d/%d high-SNR trials.',successes,trials);
end

function test_misalignment(cfg)
alignedErrors = 0;
offsetErrors = 0;
for packet = 1:40
    base = struct('frameId',packet,'symbolsPerHop',8,'ebNoDb',14, ...
        'jammerOccupancy',0,'acquire',false, ...
        'noiseSeed',cfg.seeds.noise+packet);
    aligned = simulate_packet(cfg,base,'symbol');
    base.codeOffset = 1;
    offset = simulate_packet(cfg,base,'symbol');
    alignedErrors = alignedErrors + aligned.bitErrors;
    offsetErrors = offsetErrors + offset.bitErrors;
end
assert(alignedErrors < offsetErrors && offsetErrors/(40*cfg.payloadBits) > 0.10, ...
    'One-hop code offset did not produce the expected degradation.');
end

function test_base_matlab_dependencies(~)
[~,products] = matlab.codetools.requiredFilesAndProducts('run_all.m');
if isempty(products)
    return;
end
names = {products.Name};
unexpected = setdiff(names,{'MATLAB'});
assert(isempty(unexpected),'Unexpected product dependency: %s',strjoin(unexpected,', '));
end

function test_fixed_equivalence(cfg)
for packet = 1:20
    scenario = struct('frameId',packet,'symbolsPerHop',8,'ebNoDb',6, ...
        'jammerOccupancy',0,'acquire',false, ...
        'noiseSeed',cfg.seeds.noise+packet,'hopSeed',cfg.seeds.hop+packet);
    hopped = simulate_packet(cfg,scenario,'symbol');
    scenario.linkType = 'fixed_random';
    fixed = simulate_packet(cfg,scenario,'symbol');
    assert(hopped.bitErrors == fixed.bitErrors && hopped.packetError == fixed.packetError, ...
        'No-jammer FHSS and fixed links diverged in packet %d.',packet);
end
end
