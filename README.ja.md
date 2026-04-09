# GestureFire

キーボードショートカットをトリガーするための、macOS 向けカスタムトラックパッドジェスチャーアプリ。

[English](README.md) | [中文说明](README.zh-CN.md)

GestureFire は、独自のトラックパッドジェスチャーをキーボードショートカットに割り当てるための macOS メニューバーアプリです。現在は TipTap、コーナータップ、複数指タップ、複数指スワイプをサポートし、replay ベースの回帰テストと今後のチューニング基盤も備えています。

## 何ができるのか

macOS 標準のトラックパッドジェスチャーは固定されています。GestureFire は、より自由にカスタマイズしたい人向けです。

- カスタムジェスチャーでアプリのショートカットを発火
- コーナータップや複数指ジェスチャーを追加
- 自分の操作感に合わせて感度を調整
- replay とテストで認識ロジックを安全に改善

現在、このプロジェクトは MVP 段階に到達しています。

## 現在の機能

- **19 種類のジェスチャー**
- **4 つの recognizer**：`TipTap`、`CornerTap`、`MultiFingerTap`、`MultiFingerSwipe`
- メニューバーアプリ + 設定画面
- 初回セットアップ用のオンボーディングと練習フロー
- 診断、ログ、サウンドフィードバック、ステータスパネル、ログイン時起動
- **215 テスト / 44 スイート**
- **19 個の replay fixture** による回帰保護

## ジェスチャーファミリー

- **TipTap**：4 方向
- **Corner Tap**：4 つの角
- **Multi-Finger Tap**：3 本 / 4 本 / 5 本タップ
- **Multi-Finger Swipe**：3 本 / 4 本の 4 方向スワイプ

## 現在の MVP 状態

GestureFire は、実用的な MVP と言える状態です。

- コア認識パイプラインが実装済み
- 実機での検証済み
- 高度な感度設定 UI あり
- 現在の UI に対する accessibility 基線あり
- replay ベースの回帰保護あり

既知の制限:

- 複数指スワイプは指の並び方にまだ少し敏感
- macOS のシステムジェスチャーが 3 本 / 4 本スワイプと衝突する場合がある
- オンボーディングの practice は現在 TipTap 中心

これらは MVP の妨げではなく、後続フェーズで改善予定です。

## クイックスタート

### 必要条件

- macOS 14+
- `/Applications/Xcode.app` にインストールされた Xcode

### ビルド

```bash
swift build
./scripts/build-app.sh debug
open dist/GestureFire.app
```

Release ビルド:

```bash
./scripts/build-app.sh release
```

### テスト

Swift Testing は Xcode 同梱ツールチェーンを必要とします:

```bash
./scripts/test.sh
```

同等の直接コマンド:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

## ドキュメント

- [ROADMAP](ROADMAP.md)
- [REVIEW](REVIEW.md)
- [Architecture Overview](docs/architecture/overview.md)
- [Phase 3 Spec](docs/phases/PHASE-3.md)
- [Phase 3 Acceptance](docs/PHASE-3-ACCEPTANCE.md)

## ロードマップ概要

- Phase 1: Core Loop — 完了
- Phase 1H: Hardening — 完了
- Phase 1.5: Onboarding + Verification + Sample Capture — 完了
- Phase 2: Experience Polish — 完了
- Phase 2.5: UI Structure Polish — 完了
- Phase 2.6: Visual Polish — 完了
- Phase 3: More Gestures — 完了
- Phase 4: Smart Tuning — 次
- Phase 5: Personalization — 予定

## 技術メモ

GestureFire は OpenMultitouchSupport を使って生のトラックパッド入力を取得します。認識ロジックは `TouchFrame` 抽象を介して OMS 依存から分離されており、これが replay テストや今後のキャリブレーション機能の基盤になっています。
