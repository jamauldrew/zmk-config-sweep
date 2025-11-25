#!/usr/bin/env bash
# zmk-map.sh  - show ZMK keymap layer in a tidy grid and optionally search for a token
# Usage: zmk-map.sh <keymap-file> <layer-name> [cols] [search-token]
# Example: ./zmk-map.sh config/cradio.keymap default_layer 10 EQUAL

set -euo pipefail

file="$1"
layer="$2"
cols="${3:-10}"
search="${4:-}"

if [ ! -f "$file" ]; then
  echo "File not found: $file" >&2
  exit 2
fi

# extract the bindings block for the named layer
bindings=$(awk -v L="$layer" '
  BEGIN{inlayer=0; inbind=0}
  $0 ~ "^[[:space:]]*"L"[[:space:]]*\\{" { inlayer=1; next }
  inlayer && $0 ~ "bindings[[:space:]]*=[[:space:]]*<" { inbind=1; next }
  inbind {
    if ($0 ~ ">;") { sub(">;.*",""); print; exit }
    # strip end-of-line comments and keep content
    sub("//.*","")
    print
  }
' "$file")

if [ -z "$bindings" ]; then
  echo "Layer '$layer' or its bindings block not found in $file" >&2
  exit 3
fi

# normalize into a single space-separated string of tokens
# - collapse newlines
# - remove C-style comments
# - normalize common ZMK tokens so output is readable
processed=$(printf '%s\n' "$bindings" \
  | sed -E 's:/\*.*\*/::g' \
  | tr '\n' ' ' \
  | sed -E 's/[[:space:]]+/ /g' \
  | sed -E 's/&kp[[:space:]]+([A-Za-z0-9_()]+)/\1/g' \
  | sed -E 's/&lt[[:space:]]*([0-9]+)[[:space:]]+([A-Za-z0-9_()]+)/LT\1(\2)/g' \
  | sed -E 's/&trans/TRAN/g' \
  | sed -E 's/&caps_word/CAPS/g' \
  | sed -E 's/&sys_reset/SYS_RESET/g' \
  | sed -E 's/&,/ /g' \
  | sed -E 's/,/ /g' \
  | sed -E 's/HRML\(/HRML(/g' \
  | sed -E 's/HRMR\(/HRMR(/g' \
  | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')

# split and print grid
print_grid() {
  local text="$1"
  IFS=' ' read -r -a arr <<< "$text"
  n=${#arr[@]}
  echo
  echo "Layer: $layer    (cols: $cols)    tokens: $n"
  printf '┌'; for ((i=0;i<cols;i++)); do printf '────────┬'; done; printf '\b┐\n'
  for ((i=0;i<n;i++)); do
    if (( i % cols == 0 )); then printf '│ '; fi
    printf '%-6s ' "${arr[i]}"
    if (( (i+1) % cols == 0 )); then printf '│\n'; fi
  done
  # close last row if partial
  if (( n % cols != 0 )); then
    # fill remainder
    rem=$(( cols - (n % cols) ))
    for ((j=0;j<rem;j++)); do printf '       '; done
    printf '│\n'
  fi
  printf '└'; for ((i=0;i<cols;i++)); do printf '────────┴'; done; printf '\b┘\n'
  echo
}

print_grid "$processed"

if [ -n "$search" ]; then
  # search token (case-sensitive) and print positions
  IFS=' ' read -r -a arr <<< "$processed"
  found=0
  for i in "${!arr[@]}"; do
    if [ "${arr[$i]}" = "$search" ]; then
      idx=$((i+1))
      row=$(( (i / cols) + 1 ))
      col=$(( (i % cols) + 1 ))
      printf 'Found %s at index %d (row %d, col %d)\n' "$search" "$idx" "$row" "$col"
      found=1
    fi
  done
  if [ $found -eq 0 ]; then
    echo "Token '$search' not found in layer '$layer'."
  fi
fi

exit 0
