# Simple Live Streaming Demo

D言語によるシンプルな片方向ライブ配信基盤。

FFmpeg から MPEG-TS を受け取り、HLS セグメントに分割して HTTP で配信する。

## ビルド

```bash
dub build
```

## 使い方

### サーバーモード

FFmpeg でエンコードした MPEG-TS を Packager で HLS に変換し、HTTP で配信する。

```bash
# テストソース (FFmpeg 内蔵パターン) で起動
./build/simple-live-demo

# 動画ファイルを入力にする
./build/simple-live-demo -i /path/to/video.mp4 -f ""
```

ブラウザで http://localhost:8080 を開くと視聴できる。

### Packager 単体モード

MPEG-TS ファイルを直接 HLS セグメントに分割する。

```bash
# ファイル入力
./build/simple-live-demo packager -i test.ts -o work/

# stdin から
cat test.ts | ./build/simple-live-demo packager -o work/
```

### テスト用映像の生成

```bash
# テスト用 MPEG-TS を生成 (20秒, 4秒キーフレーム間隔)
./scripts/generate_test_ts.sh

# 長さ・出力先を指定
./scripts/generate_test_ts.sh output.ts 60

# ビルド + 生成 + Packager 分割を一括実行
./scripts/test.sh
```

## アーキテクチャ

```
FFmpeg → MPEG-TS pipe → D Packager → .ts + .m3u8 → HTTP Server → ブラウザ (hls.js)
```

## 仕様参照

### HLS (HTTP Live Streaming)

- [RFC 8216 - HTTP Live Streaming](https://datatracker.ietf.org/doc/html/rfc8216) — HLS の基本仕様 (Media Playlist, Segment)

### MPEG-TS (MPEG Transport Stream)

- [MPEG-TS パケット構造 (Wikipedia)](https://en.wikipedia.org/wiki/MPEG_transport_stream#Packet) — パケットヘッダ、adaptation field、PID 等の概要
