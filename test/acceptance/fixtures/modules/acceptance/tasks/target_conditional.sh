#!/bin/bash
hostname=$(hostname)
if [[ "$hostname" == ${PT_succeed_on}* ]]; then
  echo "{\"status\": \"success\", \"hostname\": \"$hostname\"}"
  exit 0
else
  echo "{\"status\": \"failure\", \"hostname\": \"$hostname\"}" >&2
  exit 1
fi
