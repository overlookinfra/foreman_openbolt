#!/bin/bash
jq -n --arg msg "$PT_message" --arg host "$(hostname)" \
  '{"message": $msg, "hostname": $host}'
