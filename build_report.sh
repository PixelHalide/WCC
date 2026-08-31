#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
if [[ ! -f report/report.md ]]; then
  print -u2 "report/report.md is missing. Run MATLAB run_all first."
  exit 1
fi
required=(
  hop_pattern.png
  transmit_waveform.png
  spectrograms.png
  transmit_receive_spectrum.png
  tx_rx_block_diagram.png
  ber_occupancy_hoprate.png
  per_occupancy_hoprate.png
  hop_rate_mismatch.png
  fhss_fixed_comparison.png
)
for figure in "${required[@]}"; do
  if [[ ! -f "report/figures/$figure" ]]; then
    print -u2 "Missing report/figures/$figure. Run MATLAB run_all first."
    exit 1
  fi
done
pandoc report/report.md \
  --from markdown+tex_math_dollars \
  --resource-path=report \
  --standalone \
  -V geometry:margin=1in \
  -V colorlinks=true \
  -V linkcolor=blue \
  -o report/FHSS_Project_Report.tex

(
  cd report
  xelatex -interaction=nonstopmode -halt-on-error \
    FHSS_Project_Report.tex >/dev/null
  xelatex -interaction=nonstopmode -halt-on-error \
    FHSS_Project_Report.tex >/dev/null
  xelatex -interaction=nonstopmode -halt-on-error \
    FHSS_Project_Report.tex >/dev/null
)

print "Created report/FHSS_Project_Report.tex"
print "Compiled report/FHSS_Project_Report.pdf with XeLaTeX"
