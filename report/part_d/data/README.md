# Data provenance

These three tables are preserved from Git commit `8a3fb1071abecf4e1fd5ae6a9e0041b0447d7664` to match the supplied handwritten Part B report. They are historical results, not the corrected October 2026 rerun in the repository's main `results/` directory.

Part B's 1,250 hops/s, 10 dB, 25% occupancy value is BER 0.050109375; its no-jammer result is 2 payload errors in 512,000 bits. These identify the archived dataset. All Part D tables and figures use this same archived dataset consistently. The comparison with fixed links is the archived idealized symbol-model comparison, not the waveform grid.

Regenerate the figures from the repository root with `addpath('report/part_d'); make_part_d_figures;` in MATLAB. The separate current project report continues to use the corrected code and current results.
