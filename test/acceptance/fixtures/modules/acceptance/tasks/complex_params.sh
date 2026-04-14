#!/bin/bash
# Echo back all parameters as JSON so the test can verify they arrived correctly.
# PT_array_param arrives as a JSON string from bolt, so we pass it through as raw JSON.
jq -n \
  --arg required "$PT_required_string" \
  --arg optional "$PT_optional_string" \
  --argjson array "${PT_array_param:-null}" \
  --arg default_val "$PT_with_default" \
  --argjson hash "${PT_hash_param:-null}" \
  '{
    required_string: $required,
    optional_string: (if $optional == "" then null else $optional end),
    array_param: $array,
    with_default: $default_val,
    hash_param: $hash
  }'
