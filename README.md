# Room Breaker 3D

Godot 4.x で作成した、Android 向けの 3D ブロック崩しゲームです。立方体の部屋の中で Paddle を左右に動かし、Ball を跳ね返してすべての Block を破壊します。

## 操作

- **Android**: 画面下半分のタッチ / スワイプで Paddle を左右移動
- **Android デバッグ視点**: 画面上半分で開始したスワイプでカメラ回転
- **PC**: マウス移動で Paddle を左右移動
- **PC 補助操作**: `A` / `D` キーで Paddle を左右移動
- **PC デバッグ視点**: 右ドラッグでカメラ回転、マウスホイールでズーム

## ゲームルール

- 上部のブロックに Ball が当たるとブロックが破壊され、スコアが加算されます
- すべてのブロックを壊すとクリアです
- Ball が床下に落ちると 1 ミスです
- 残機が 0 になるとゲームオーバー後に自動で再スタートします

## プロジェクト構造

```text
res://
├── Main.tscn
├── README.md
├── export_presets.cfg
├── icon.svg
├── project.godot
├── scenes
│   ├── Ball.tscn
│   ├── Block.tscn
│   ├── BlockManager.tscn
│   ├── Paddle.tscn
│   ├── Room.tscn
│   └── UI.tscn
└── scripts
    ├── ball.gd
    ├── block.gd
    ├── block_manager.gd
    ├── main.gd
    ├── paddle.gd
    └── ui.gd
```

## ローカル実行

Godot 4.x エディタでこのディレクトリを開き、`Main.tscn` を実行してください。

CLI から起動する場合:

```bash
./Godot_v4.2.2-stable_linux.x86_64 --path . Main.tscn
```

## Android ビルド

このリポジトリには Android export preset が含まれています。署名情報は含めていないため、必要に応じて次のいずれかを設定してください。

1. Godot Editor の **Editor Settings > Export > Android** で debug / release keystore を設定
2. CI から `GODOT_ANDROID_KEYSTORE_DEBUG_PATH` などの環境変数を渡す

GitHub Actions を使う場合は、既存の `.github/workflows/android.yml` が APK export を行います。
