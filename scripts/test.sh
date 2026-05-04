#!/bin/bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
WORK_DIR="$PROJECT_DIR/work"
TEST_TS="$PROJECT_DIR/test.ts"

# テスト用MPEG-TS生成 (20秒, 720p, 4秒キーフレーム間隔)
generate() {
    echo "Generating test MPEG-TS: $TEST_TS"
    ffmpeg -y -f lavfi -i testsrc2=size=1280x720:rate=30 \
        -f lavfi -i sine=frequency=440:sample_rate=48000 \
        -c:v libx264 -preset ultrafast -b:v 2M \
        -c:a aac -b:a 128k \
        -force_key_frames "expr:gte(t,n_forced*4)" \
        -t 20 -f mpegts "$TEST_TS"
    echo "Done: $(du -h "$TEST_TS" | cut -f1)"
}

# Packager単体テスト
packager() {
    rm -rf "$WORK_DIR"
    mkdir -p "$WORK_DIR"
    echo "Running packager..."
    "$PROJECT_DIR/build/simple-live-example" packager -i "$TEST_TS" -o "$WORK_DIR"
    echo ""
    echo "=== Segments ==="
    ls -lh "$WORK_DIR"/*.ts 2>/dev/null || echo "(none)"
    echo ""
    echo "=== Playlist ==="
    cat "$WORK_DIR/stream.m3u8" 2>/dev/null || echo "(none)"
}

# ビルド + テスト一括
all() {
    (cd "$PROJECT_DIR" && dub build)
    if [ ! -f "$TEST_TS" ]; then
        generate
    fi
    packager
}

case "${1:-all}" in
    generate) generate ;;
    packager) packager ;;
    all)      all ;;
    *)        echo "Usage: $0 {generate|packager|all}" ;;
esac
