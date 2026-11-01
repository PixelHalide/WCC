# MATLAB code walkthrough

This guide is for someone who already understands programming but is new to MATLAB. It uses this repository's FHSS (frequency-hopping spread spectrum) simulation as the example. You can read it before installing MATLAB; to run the examples, follow the installation and launch instructions in [README.md](README.md).

## The short version

The project makes a packet, converts its bits into a radio waveform, adds interference and noise, tries to recover the packet, then repeats that experiment many times to estimate error rates.

```text
run_quick / run_all
        |
        +--> fhss_config       settings
        +--> build_frame       preamble + header + payload + CRC
        +--> fhss_transmitter  bits -> sampled hopping waveform
        +--> apply_fhss_channel  add jammer + noise
        +--> fhss_receiver    synchronize + dehop + decode + CRC check
        +--> run_experiments  repeat scenarios and write tables
```

The ordinary end-to-end path is `simulate_packet`. The `waveform` mode models actual samples and is used for the main FHSS results. The `symbol` mode is a faster, simplified model used for selected fixed-frequency comparisons.

## MATLAB in five minutes

### A MATLAB file is usually a function

For example, `src/config/fhss_config.m` starts with:

```matlab
function cfg = fhss_config(overrides)
```

This defines a function named `fhss_config`. It accepts an input called `overrides` and returns a value called `cfg`. MATLAB finds the function by its filename, so this function lives in `fhss_config.m`. Run it by typing:

```matlab
cfg = fhss_config();
```

The parentheses call the function; the semicolon suppresses printing the result. Without a semicolon, MATLAB displays the result in the Command Window.

The `function` line must be first in a function file (comments may precede it). Some files have helper functions below the main one. Those helpers are available to that file, but generally aren't meant to be called from elsewhere.

### Variables do not need declarations

```matlab
ebNoDb = 10;
message = "hello";
```

MATLAB creates the variable when it first appears. Names are case-sensitive: `ebNoDb` and `EbNoDb` are different names.

### Arrays are the main building block

MATLAB is designed around arrays. These examples make a row of values and select part of it:

```matlab
channels = [1 2 3 4];  % a row vector
channels(2)            % 2: MATLAB positions start at 1
channels(2:4)           % [2 3 4]; the colon makes a range
channels(end)           % last value, 4
```

Unlike Python, MATLAB indexing starts at **1**, not 0. The colon operator also makes regularly spaced values: `0:2:14` means 0, 2, 4, ..., 14.

Parentheses select values; square brackets join values. For example, `[a b]` concatenates `a` and `b` horizontally. A semicolon inside square brackets starts a new row. A semicolon at the end of a statement suppresses its display.

### Pay attention to row and column shape

`[1 2 3]` is a row, while `[1; 2; 3]` is a column. This project often reshapes incoming bits into a row so they can be concatenated and processed consistently:

```matlab
frameBits = double(frameBits(:).');
```

Read this from the inside out: `(:)` makes a column containing all elements, and `.'` transposes it to a row. `double(...)` converts the values to MATLAB's standard floating-point number type. (`.'` is a plain transpose; `'` also conjugates complex numbers.)

### Element-by-element math uses a dot

MATLAB uses `*` for matrix multiplication and `.*` for multiplying corresponding elements. Similarly, `./` and `.^` apply division and powers element by element. For example:

```matlab
frequencies = [10 20 30];
phases = 2*pi .* frequencies ./ 100;
```

In signal code, the dot is common because each sample gets its own frequency or phase. Missing a dot can change the meaning or cause a size error.

### Structs hold named fields

A struct is similar to a small object or dictionary:

```matlab
cfg.sampleRateHz = 500e3;
cfg.symbolRateHz = 10e3;
```

`cfg.sampleRateHz` accesses one field. This project passes a `cfg` struct for settings and returns structs such as `out` and `receiver` for results. A dot accesses a field; it is not multiplication.

### `if`, `for`, and `while` look familiar

MATLAB closes blocks with a separate `end`:

```matlab
for occupancy = [0 0.25 0.5]
    fprintf('Occupancy: %.0f%%\n', 100*occupancy);
end
```

`for occupancy = values` takes each value in turn. `if condition ... else ... end` chooses a branch. `while condition ... end` repeats until the condition is false. These forms appear in `run_experiments.m`.

### A few MATLAB-specific types in this repo

- `struct(...)` creates a struct with named fields.
- `{...}` creates a cell array. Cells can hold different kinds or sizes of values. `rows` in `run_experiments.m` is a cell array because each table row combines numbers and text labels.
- `table(...)` and `cell2table(...)` create labeled columns, convenient for saving results to CSV.
- `RandStream(...)` creates a seeded random-number stream. Fixed seeds make a run reproducible.
- A character vector uses single quotes (`'waveform'`); a string uses double quotes (`"waveform"`). This code uses both forms in different places.

## Get the code running

From the repository root in MATLAB, try the short run first:

```matlab
run_quick
```

`run_quick.m` is a function file, so writing `run_quick` calls it. It changes to the project directory, adds `src/` and `tests/` (including their subfolders) to MATLAB's search path, runs deterministic tests, and simulates one packet. Its last line prints a BER, CRC result, and synchronization result.

For an interactive session, add source folders once and inspect a baseline packet:

```matlab
addpath(genpath('src'))
cfg = fhss_config();
scenario = struct('frameId', 1, 'ebNoDb', 10, ...
    'jammerOccupancy', 0.25, 'acquire', true);
out = simulate_packet(cfg, scenario, 'waveform');
out.ber
out.crcOk
out.syncSuccess
```

The three dots `...` mean “continue this statement on the next line.” `out.ber` reads the BER field of the returned struct. You can type `whos` to list variables in the workspace or `out` to display the output struct.

`run_all` runs tests, creates a baseline demo, runs the Monte Carlo studies, saves CSV/MAT results, draws figures, and refreshes report data. It takes much longer than `run_quick`; use it when you actually want to regenerate the evidence.

## Follow one packet through the code

### 1. Settings: `src/config/fhss_config.m`

`fhss_config()` builds a `cfg` struct. Fields ending in `Hz` are frequencies. `500e3` means 500,000 samples per second; `2.4e9` means 2.4 billion Hz. The code uses a low-frequency sampled representation labeled as a 2.4 GHz link, rather than simulating 2.4 billion samples per second.

The function derives values such as `samplesPerSymbol` from the primary settings, merges any overrides, and validates them. MATLAB's `error(...)` stops with a readable message when settings are inconsistent. For example, the frame length must divide evenly into `symbolsPerHop`.

### 2. Frame: `src/transmitter/build_frame.m`

`build_frame` creates a 320-bit frame:

```text
32-bit preamble | 16-bit packet counter | 256-bit payload | 16-bit CRC
```

The payload is generated from a seeded random stream unless you pass one in. A seed is like a repeatable starting state for a random-number generator: the same seed gives the same sequence. The function returns both the combined `frame.bits` and the named pieces (`frame.payload`, `frame.header`, and so on).

### 3. Transmit: `src/transmitter/fhss_transmitter.m`

The transmitter maps each bit to a BPSK symbol (`0` becomes `+1`, `1` becomes `-1`), repeats each symbol to make samples, and multiplies those samples by a complex sinusoid at the selected hop frequency. The `1j` value is MATLAB's imaginary unit. The returned `tx` struct keeps the waveform and useful intermediate values for inspection.

### 4. Hop schedule: `src/hopping/`

`hop_sequence.m` creates a repeatable pseudo-random sequence of channel numbers. Each block visits all eight channels once in a shuffled order. `carrier_schedule.m` expands those hop choices so every waveform sample has a channel assignment. The transmitter and receiver use the same seeded sequence, which lets the receiver follow the transmission once it has the correct starting hop and timing.

### 5. Channel: `src/channel/apply_fhss_channel.m`

The channel adds three sample arrays: the desired waveform, a partial-band jammer, and additive white Gaussian noise (AWGN). The jammer affects selected channels; the noise affects the whole signal. Separate seeded streams make the jammer, noise, and timing repeatable independently.

### 6. Receive: `src/receiver/`

`fhss_receiver.m` coordinates recovery. If acquisition is enabled, `acquire_hop_sync.m` searches for the likely timing and hop-code offset. `dehop_and_demodulate.m` multiplies by the opposite-frequency sinusoid to bring the desired signal back to baseband, averages the samples for each symbol, and decides whether each bit is 0 or 1. Then the receiver locates the preamble, extracts header and payload, and recomputes the CRC.

The returned receiver struct has fields such as `sync`, `softSymbols`, `bits`, `payload`, and `crcOk`. `softSymbols` are the measured symbol values before converting them to hard 0/1 decisions; they are useful when debugging a noisy packet.

### 7. Packet score: `simulate_packet.m`

`simulate_packet` connects the frame, transmitter, channel, and receiver. Its output includes `bitErrors`, `ber`, `packetError`, `syncSuccess`, and `crcOk`. BER is payload bit errors divided by payload bits. A packet error is recorded if synchronization or CRC fails.

## From one packet to results

`run_experiments.m` repeats packets under combinations of settings. Its loops vary hop rate, jammer occupancy, and signal-to-noise ratio (`EbNoDb`). For each trial it changes the random seeds, calls `simulate_packet`, and adds errors to totals. The performance study stops after at least 250 packets and after enough packet errors have accumulated, or at 2,000 packets.

At the end, the code calculates BER (bit error rate), PER (packet error rate), and 95% Wilson confidence intervals, then writes tables into `results/`. `run_all.m` is the top-level orchestrator: it runs tests, calls the studies, saves complete MATLAB structs (`.mat`), draws figures, and generates report data.

`tests/run_tests.m` contains checks for known CRC output, frame structure, deterministic hopping, noiseless packet recovery, synchronization, and invalid inputs. A test's `assert(...)` stops that check if its condition is false. The test runner catches failures, prints a summary, and reports an error if any test failed.

## How to change a scenario

Make a new scenario struct and pass it to `simulate_packet`; omitted fields use defaults:

```matlab
scenario = struct('frameId', 7, ...
    'symbolsPerHop', 4, ...
    'ebNoDb', 12, ...
    'jammerOccupancy', 0.125, ...
    'jsDb', 10, ...
    'acquire', true);
out = simulate_packet(fhss_config(), scenario, 'waveform');
```

Smaller `symbolsPerHop` means the radio changes channel more often. The hop rate is `symbolRateHz / symbolsPerHop`; with the default 10 ksymbol/s rate, 4 symbols per hop is 2,500 hops/s. Higher `ebNoDb` means less noise relative to the signal. `jammerOccupancy` is the fraction of channels jammed; with eight channels it must select a whole number of channels, so values such as 0, 0.125, 0.25, and 0.5 are valid. `jsDb` sets aggregate jammer-to-signal power in decibels.

To compare no-jammer behavior, set both `jammerOccupancy` to `0` and `jsDb` to `Inf`. To run without noise, set `ebNoDb` to `Inf`. For a new experiment grid, edit `cfg.experiment` in `fhss_config.m`, then rerun `run_all`; note that this overwrites generated outputs under `results/` and report figures.

## Where to look next

- [README.md](README.md) for installation, commands, and the full folder map.
- [report/SIMPLE_EXPLANATION.md](report/SIMPLE_EXPLANATION.md) for the communications concepts without focusing on MATLAB syntax.
- `src/analysis/simulate_packet.m` for the one-packet call flow.
- `src/analysis/run_experiments.m` for the repeated experiments and statistics.
- `tests/run_tests.m` for small examples of expected behavior.

When learning, change one input at a time and inspect the returned struct. A small, repeatable packet run is easier to understand than starting with the full Monte Carlo run.
