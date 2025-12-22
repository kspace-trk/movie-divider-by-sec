# Movie Divider by Sec

Desktopの動画ファイルを1分（60秒）ごとに自動分割するシェルスクリプトです。

- `~/Desktop/input.mov` または `~/Desktop/input.mp4` を自動検出
- 1分（60秒）ごとに分割して `~/Desktop/out_000.mp4`, `out_001.mp4`, ... として出力
- 再エンコードなしで高速処理（元の品質を維持）
- 1分未満の動画はスキップ

## コマンド

```bash
bash <(curl -s https://raw.githubusercontent.com/kspace-trk/movie-divider-by-sec/main/split_video.sh)
```
