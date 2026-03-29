#!/usr/bin/env bash
# Crypto ticker plugin — BTC and ETH from CoinGecko (free, no key)
set -euo pipefail

DATA=$(curl -s --max-time 10 "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum&vs_currencies=usd&include_24hr_change=true" 2>/dev/null || true)

if [ -z "$DATA" ]; then
  curl -s -X POST localhost:7070/notify \
    -H "Content-Type: application/json" \
    -d "{
    \"source\": \"crypto\",
    \"level\": \"passive\",
    \"title\": \"CRYPTO: API ERROR\",
    \"renderer\": \"lcd\",
    \"presentation\": \"static\",
    \"size\": \"medium\",
    \"color\": \"red\"
  }"
  exit 0
fi

# Parse with python3 (always available on macOS)
TICKER=$(echo "$DATA" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    btc = d['bitcoin']['usd']
    eth = d['ethereum']['usd']
    btc_chg = d['bitcoin'].get('usd_24h_change', 0)
    eth_chg = d['ethereum'].get('usd_24h_change', 0)
    btc_arrow = '+' if btc_chg >= 0 else '-'
    eth_arrow = '+' if eth_chg >= 0 else '-'
    print(f'BTC {btc:,.0f}{btc_arrow} ETH {eth:,.0f}{eth_arrow}')
except Exception:
    print('CRYPTO: PARSE ERROR')
" 2>/dev/null || echo "CRYPTO: PARSE ERROR")

# Color based on BTC trend
COLOR="amber"
if echo "$DATA" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d['bitcoin'].get('usd_24h_change',0) >= 0 else 1)" 2>/dev/null; then
  COLOR="green"
else
  COLOR="red"
fi

curl -s -X POST localhost:7070/notify \
  -H "Content-Type: application/json" \
  -d "{
  \"source\": \"crypto\",
  \"level\": \"passive\",
  \"title\": \"$TICKER\",
  \"renderer\": \"lcd\",
  \"presentation\": \"static\",
  \"size\": \"medium\",
  \"color\": \"$COLOR\"
}"
