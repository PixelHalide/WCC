#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
pandoc report/part_d/PART_D.md --standalone --resource-path=report/part_d \
  --from markdown+tex_math_dollars -o report/part_d/PART_D.tex
(
  cd report/part_d
  for pass in 1 2 3; do
    xelatex -interaction=nonstopmode -halt-on-error \
      PART_D.tex > /dev/null
  done
)
print "Created report/part_d/PART_D.pdf"
