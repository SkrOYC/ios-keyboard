#!/usr/bin/env zsh
set -euo pipefail

nixfmt --check devenv.nix
actionlint
shellcheck --shell=bash .envrc
for script in scripts/*.zsh; do
  zsh -n "$script"
done
python3 scripts/check-config.py
python3 -m unittest discover -s tests -v
python3 scripts/gen-geometry-fixture.py --check
python3 scripts/check-spec-parity.py
