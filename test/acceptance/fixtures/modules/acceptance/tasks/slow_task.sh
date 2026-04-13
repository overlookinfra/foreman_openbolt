#!/bin/bash
sleep "${PT_seconds:-5}"
echo "{\"status\": \"ok\", \"slept\": ${PT_seconds:-5}}"
