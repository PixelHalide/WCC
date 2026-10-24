# Code cleanup and verification status

Reviewed on 24 October 2026; runtime verification completed on 25 October 2026.

## Correctness fixes

- Apply `scenario.hopSeed` consistently to transmitter and receiver. Previously Monte Carlo assigned a new seed per packet, but FHSS silently kept the configuration seed.
- Add `txCodeOffset` to inject a transmitter code phase. Acquisition regression tests now recover nonzero phases as well as timing offsets.
- Reject truncated waveforms with an unavailable (`NaN`) payload and failed synchronization/CRC rather than parsing fabricated hard decisions.
- In symbol mode, calculate jammer collisions on the receiver's listening channel when the hopping schedules differ.
- Select recommended hop rates using actual acquisition trials. Previously the eligibility filter used frame detection with known timing instead.
- Validate scenario inputs before generating waveforms and keep derived configuration values consistent with rate/frame overrides.

## Simplifications

- Remove unused configuration and confidence-interval variables.
- Remove the schedule gap-filling loop: successive rounded dwell boundaries are contiguous by construction.
- Permit a jammed demonstration to fail acquisition; it is experimental evidence, not a deterministic test.
- Point `run_all` at the existing report build script.
- Describe symbol mode as an idealized comparison rather than claiming waveform equivalence under interference.

## Verification

MISS_HIT parsed and linted all 28 MATLAB files successfully. Git whitespace checks passed. Four regression tests were added (packet seeds, truncated frames, fractional dwell boundaries, and invalid scenarios); the acquisition test was strengthened.

Verified using native Apple-silicon MATLAB 26.2.0.3386108 (R2026b). All 13 tests passed. `run_all` completed and regenerated CSV/MAT evidence, figures, and report source. The PDF compiled with XeLaTeX without reported warnings or errors.

Additional runtime checks passed for exact seeded packet replay, derived configuration fields, and acquisition with nonzero code phase at the last sample of a dwell for all three hop rates. Generated tables passed checks for dimensions, packet limits, finite BER/PER values, count-to-rate consistency, and confidence bounds. The experiment includes 96 performance points, 27 mismatch/acquisition cases, 32 fixed-link cases, and 3 model cross-checks.

The corrected selection rule still recommends eight channels at 1,250 hops/s. Acquired synchronization probabilities at 10 dB with 25% jamming were 0.72, 0.90, and 0.92 for 625, 1,250, and 2,500 hops/s respectively (50 trials per rate). The symbol/waveform confidence intervals overlap in the no-jammer case but not in either jammer case; this remains a documented model limitation rather than a passing equivalence claim.

With base MATLAB available, run from the repository root:

```matlab
run_quick;
run_all;
```

Then rebuild the report:

```sh
zsh build_report.sh
```

## Model limits that remain

Symbol mode has ideal channel isolation, no timing search, and a symbol-center approximation for dwell errors. Use waveform mode for synchronization and mismatch studies. Waveform performance curves use supplied timing; acquisition trials are a separate study. Payload BER intervals currently use a binomial approximation even though jammer errors can be correlated within hops. The fixed-link comparison uses the idealized symbol model. These are modeling limitations, not claims of a measured hardware link.
