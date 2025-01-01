#!/usr/bin/env bash

set -euo pipefail

MODULE_NAME="$(
  grep -A1 -E "module\\(" MODULE.bazel | xargs |
  tr -d "," | awk '{print $NF}'
)"

for module in . docs tests examples e2e e2e/smoke; do
  [[ ! -f "${module}/MODULE.bazel" ]] && continue

  pushd "${module}" > /dev/null

  echo
  if [[ "${module}" == "." ]]; then
    echo "--- [${MODULE_NAME}] --------------------------------"
  else
    echo "--- [${MODULE_NAME}/${module}] --------------------------------"
  fi
  echo

  # NOTE:
  # "no test targets" error (exit code 4) is allowed.
  # See the Bazel wrapper in tools/bazel
  bazel test //...

  popd > /dev/null
done
