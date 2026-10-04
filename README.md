# Movie Divider by Sec

動画ファイルを1分を超えない長さに自動分割するシェルスクリプトです。

- 引数でファイルパス（`.mov` / `.mp4`）を指定した場合はそのファイルを入力に使用
- 引数がない場合は `~/Desktop/input.mov` または `~/Desktop/input.mp4` を自動検出
- 1分を超えないように（各ファイル最大59.5秒）分割して `~/Desktop/out_000.mp4`, `out_001.mp4`, ... として出力
- キーフレーム位置で切るため、通常は再エンコードなしで高速処理（元の品質を維持）
- キーフレームの間隔が広すぎて59.5秒以内に切れない動画は、再エンコードして分割
- 1分未満の動画はスキップ

## コマンド

```bash
bash <(curl -s https://raw.githubusercontent.com/kspace-trk/movie-divider-by-sec/main/split_video.sh)
```

入力ファイルを指定する場合:

```bash
bash <(curl -s https://raw.githubusercontent.com/kspace-trk/movie-divider-by-sec/main/split_video.sh) /path/to/video.mp4
```
