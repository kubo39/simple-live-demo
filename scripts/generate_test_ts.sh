#!/bin/bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT="${1:-$PROJECT_DIR/test.ts}"
DURATION="${2:-20}"

echo "Generating test MPEG-TS (${DURATION}s): $OUTPUT"
ffmpeg -y \
    -f lavfi -i testsrc2=size=1280x720:rate=30 \
    -f lavfi -i sine=frequency=440:sample_rate=48000 \
    -c:v libx264 -preset ultrafast -b:v 2M \
    -force_key_frames "expr:gte(t,n_forced*4)" \
    -c:a aac -b:a 128k \
    -f mpegts -t "$DURATION" "$OUTPUT"
echo "Done: $(du -h "$OUTPUT" | cut -f1)"
