# Movie Divider by Sec

Desktopの動画ファイルを1分（60秒）ごとに自動分割するシェルスクリプトです。

- 引数でファイルパス（`.mov` / `.mp4`）を指定した場合はそのファイルを入力に使用
- 引数がない場合は `~/Desktop/input.mov` または `~/Desktop/input.mp4` を自動検出
- 1分（60秒）ごとに分割して `~/Desktop/out_000.mp4`, `out_001.mp4`, ... として出力
- 再エンコードなしで高速処理（元の品質を維持）
- 1分未満の動画はスキップ

## コマンド

```bash
bash <(curl -s https://raw.githubusercontent.com/kspace-trk/movie-divider-by-sec/main/split_video.sh)
```

入力ファイルを指定する場合:

```bash
bash <(curl -s https://raw.githubusercontent.com/kspace-trk/movie-divider-by-sec/main/split_video.sh) /path/to/video.mp4
```
