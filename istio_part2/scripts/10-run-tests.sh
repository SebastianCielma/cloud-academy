#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
python3 -m unittest discover -s tests -p 'test_*.py' -v
for script in scripts/*.sh; do
  bash -n "$script"
done
python3 -m compileall -q apps tools tests
