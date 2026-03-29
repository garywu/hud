#!/usr/bin/env bash
# Network speed plugin — sample throughput over 1 second
set -euo pipefail

# Detect default interface
IFACE=$(route get default 2>/dev/null | grep interface | awk '{print $2}' || true)
if [ -z "$IFACE" ]; then IFACE="en0"; fi

# Sample network bytes (macOS netstat -ib)
B1=$(netstat -ib -I "$IFACE" 2>/dev/null | tail -1 | awk '{print $7, $10}')
if [ -z "$B1" ]; then
  curl -s -X POST localhost:7070/notify \
    -H "Content-Type: application/json" \
    -d "{
    \"source\": \"network\",
    \"level\": \"passive\",
    \"title\": \"NET: NO INTERFACE\",
    \"renderer\": \"text\",
    \"presentation\": \"static\",
    \"size\": \"small\"
  }"
  exit 0
fi

sleep 1

B2=$(netstat -ib -I "$IFACE" 2>/dev/null | tail -1 | awk '{print $7, $10}')

IN1=$(echo "$B1" | awk '{print $1}')
IN2=$(echo "$B2" | awk '{print $1}')
OUT1=$(echo "$B1" | awk '{print $2}')
OUT2=$(echo "$B2" | awk '{print $2}')

DL=$(( (IN2 - IN1) / 1024 ))
UL=$(( (OUT2 - OUT1) / 1024 ))

# Format with units
if [ "$DL" -gt 1024 ]; then
  DL_FMT="$(( DL / 1024 ))MB"
else
  DL_FMT="${DL}KB"
fi

if [ "$UL" -gt 1024 ]; then
  UL_FMT="$(( UL / 1024 ))MB"
else
  UL_FMT="${UL}KB"
fi

curl -s -X POST localhost:7070/notify \
  -H "Content-Type: application/json" \
  -d "{
  \"source\": \"network\",
  \"level\": \"passive\",
  \"title\": \"DL:${DL_FMT}/s UL:${UL_FMT}/s\",
  \"renderer\": \"text\",
  \"presentation\": \"static\",
  \"size\": \"small\"
}"
