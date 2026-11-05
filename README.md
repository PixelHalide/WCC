# FHSS Transceiver with Hop Synchronization

This repository is a reproducible, base-MATLAB simulation for a wireless communication class project. It models a framed BPSK frequency-hopping link, partial-band interference, AWGN, hop acquisition/dehopping, frame synchronization, CRC checking, and BER/PER analysis.

## What is included

- A 320-bit frame with a 32-bit preamble, 16-bit counter, 256-bit payload, and CRC-16/CCITT-FALSE.
- Eight pseudo-random hop channels across a 195 kHz low-IF hopping band.
- Full sample-domain Tx/channel/Rx simulation and an idealized symbol-domain comparison model.
- Three hop rates, three nonzero jammer occupancies, deliberate sequence and hop-rate mismatch, and fixed-frequency comparisons.
- Deterministic tests, CSV/MAT results, reproducible figures, and an academic PDF report pipeline.

## MATLAB environment

Only base MATLAB is required; Communications Toolbox, Signal Processing Toolbox, and Simulink are not used. This project is verified with native Apple-silicon MATLAB R2026b. Pandoc and XeLaTeX are needed only to rebuild the PDF.

To reproduce the installation on another Mac:

1. Sign in to MathWorks with the college account.
2. Download the native Apple-silicon MATLAB installer.
3. Install **MATLAB only**.
4. If MATLAB does not find Java, run:

   ```bash
   /Applications/MATLAB_R2026b.app/bin/matlab_jenv \
     /Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home
   ```

5. Verify:

   ```bash
   /Applications/MATLAB_R2026b.app/bin/matlab \
     -batch "disp(version); assert(~isempty(ver('MATLAB')))"
   ```

If the desktop license is unavailable, upload this folder to MATLAB Drive and run it in MATLAB Online.

## Run the project

For a short environment and receiver check:

```bash
cd /Users/pixel/Documents/WCC
/Applications/MATLAB_R2026b.app/bin/matlab -batch "run_quick;"
```

For all tests, Monte Carlo experiments, figures, and report data:

```bash
cd /Users/pixel/Documents/WCC
/Applications/MATLAB_R2026b.app/bin/matlab -batch "run_all;"
```

The full run is intentionally longer because every BER/PER point uses at least 250 packets and up to 2,000 packets.

Generate the persistent LaTeX source and compile it with XeLaTeX after `run_all` completes:

```bash
zsh build_report.sh
```

The final file is `report/FHSS_Project_Report.pdf`.

## Main interfaces

The entry points load every source subfolder automatically. For direct function
calls in a fresh MATLAB session, first run `addpath(genpath('src'))` from the
project root.

```matlab
cfg = fhss_config();
out = simulate_packet(cfg, scenario, "waveform");
results = run_experiments(cfg);
run_all;
```

Use `mode="waveform"` for physical hopping, and timing acquisition. The faster `mode="symbol"` assumes ideal channel isolation and does not perform timing acquisition; it is only an approximate decision-level comparison. Its jammer results do not match the waveform model's asynchronous pulses and adjacent-channel leakage.

Important `scenario` fields are `symbolsPerHop`, `ebNoDb`, `jammerOccupancy`, `jsDb`, `codeOffset`, `txCodeOffset`, `hopSeed`, `rateError`, `acquire`, and `linkType`. `txCodeOffset` injects the transmitter phase that acquisition must recover; `codeOffset` forces the receiver phase when acquisition is disabled. Waveform mode supports FHSS; symbol mode also supports `fixed_jammed`, `fixed_clean`, and `fixed_random`.

Acquisition defaults to `false`. BER/PER studies use known packet timing and hop alignment (apart from deliberately imposed mismatch). The frame-synchronization panel uses a separate `acquire = true` mismatch sweep with 50 packets per point; BER/PER panels use 1,000 packets per point with `acquire = false`. The first 50 trials use matching seeds between these two cases at each setting. Explicit acquisition tests also enable it. Symbol mode does not perform acquisition. Rerun `run_all` and `zsh build_report.sh` to regenerate results and the report after changing experiment settings.

## Source layout

```text
run_all.m                  Full verification, experiments, plots and report data
run_quick.m                Tests and one baseline packet
src/
  config/                  Shared settings and validation
  transmitter/             Framing and BPSK waveform synthesis
  hopping/                 Shared hop sequence and sample-level carrier schedule
  channel/                 AWGN and partial-band jammer
  receiver/                Acquisition, dehopping, decisions and frame parsing
  analysis/                Packet simulation, experiment loops and statistics
  plotting/                FFT helpers, plots, styling and figure export
  utilities/               Bit conversions and CRC-16
  reporting/               Report generation from measured results
tests/                     Deterministic verification suite
```

Function names and simulation behaviour are unchanged by the folder split.

## Output map

- `results/*.csv`: test, hop-table, performance, mismatch, fixed-link, and model-validation tables.
- `results/*.mat`: complete MATLAB structures for later inspection.
- `report/figures/`: PNG and vector-PDF plots.
- `report/report.md`: report populated with measured values by `run_all`.
- `report/SIMPLE_EXPLANATION.md`: beginner-friendly explanation of the complete system.
- `CODE_WALKTHROUGH.md`: beginner's guide to MATLAB syntax and the project call flow.
- `report/FHSS_Project_Report.tex`: standalone LaTeX source generated by `build_report.sh`.
- `report/FHSS_Project_Report.pdf`: submission-ready report.

The main experiment uses aggregate jammer-to-signal ratio $J/S=-5$ dB; the separate historical Part D report retains its original 10 dB dataset. The generated evidence uses MATLAB R2026b. All 13 tests pass. The full run contains 96 performance points, 69 mismatch, code-offset and acquisition cases, 32 fixed-link comparisons, and 3 model cross-checks. Exact seeded packet replay and output-table consistency were also checked. To reproduce, run `run_quick` first, then `run_all` and `zsh build_report.sh`.

## Modeling boundaries

The simulation uses a complex low-IF representation labelled as a 2.4 GHz link. It assumes instantaneous switching and perfect carrier phase/frequency after dehopping. It intentionally excludes multipath fading, FEC, hardware impairments, and SDR operation.
