#!/bin/bash
# Helper to detect and optionally fix ownership of Rust tool directories
set -euo pipefail

dirs=("${CARGO_HOME:-$HOME/.cargo}" "${RUSTUP_HOME:-$HOME/.rustup}")
echo "Checking Rust directories: ${dirs[*]}"
for d in "${dirs[@]}"; do
  if [ -e "$d" ]; then
    owner=$(stat -c %U "$d" 2>/dev/null || true)
    echo "$d -> owner: ${owner:-<unknown>}"
    if [ "$owner" = "root" ]; then
      echo "Directory $d is owned by root. You can fix it with:"
      echo "  sudo chown -R $(id -u):$(id -g) $d"
      echo -n "Fix now? [y/N]: "
      read -r ans
      if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
        sudo chown -R $(id -u):$(id -g) "$d"
        echo "Fixed ownership for $d"
      else
        echo "Skipping $d"
      fi
    fi
  else
    echo "$d does not exist; no action needed"
  fi
done

echo "Ensure your shell profile exports CARGO_HOME and RUSTUP_HOME if you use non-standard locations."
echo "Example:"
echo "  export CARGO_HOME=\"$HOME/.cargo\""
echo "  export RUSTUP_HOME=\"$HOME/.rustup\""
