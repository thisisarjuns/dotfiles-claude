#!/usr/bin/env bash
# Statusline: tokens used / total context window

INPUT=$(cat)

USED=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
cw = d.get('context_window', {})
total_in = cw.get('total_input_tokens', 0)
total_out = cw.get('total_output_tokens', 0)
size = cw.get('context_window_size', 200000)
used_pct = cw.get('used_percentage', 0)
cost = d.get('cost', {}).get('total_cost_usd', 0)
model = d.get('model', {}).get('display_name', '?')

used_k = (total_in + total_out) / 1000
size_k = size / 1000

if used_pct > 80:
    color = '\033[31m'  # red
elif used_pct > 60:
    color = '\033[33m'  # yellow
else:
    color = '\033[32m'  # green
reset = '\033[0m'

print(f'{model} | {color}{used_k:.0f}k / {size_k:.0f}k ({used_pct:.0f}%){reset} | \${cost:.2f}')
" 2>/dev/null)

if [ -n "$USED" ]; then
    echo "$USED"
else
    echo "statusline error"
fi
