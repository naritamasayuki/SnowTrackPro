# SnowTrack Pro

ウェアのポケットに iPhone を入れたまま滑るだけで、GPS とモーションセンサーにより滑走データを自動計測・分析できるスキー・スノーボード向けトラッキングアプリです。

## 実装済み機能（Phase 1 完了）

- **コアロジック（Swift Package: `Packages/SnowTrackCore`）**
  - オフライン・ジオフェンシングによるスキー場自動判定（`ResortMatcher` / `resorts.json`）
  - GPS ノイズ・スパイク除去付きの滑走距離・最高速度・平均速度・獲得標高差計算（`TrackMetricsCalculator`）
  - 滑走中 / リフト乗車中 / 休憩中の自動判定ステートマシン（`RunStateMachine`）
  - ロケール追従の単位フォーマット（メートル法 / ヤード・ポンド法：`MeasurementFormatHelper`）
  - フリーミアム＋サブスクリプション機能ゲート（`EntitlementPolicy`）
- **iOS アプリ（`SnowTrackPro`）**
  - バックグラウンド位置情報取得＆状態別省電力モード切替（`LocationTrackingService`）
  - ハイコントラスト・ダークモード計測ダッシュボード＆リアルタイム MapKit 軌跡・速度ヒートマップ（`TrackingDashboardView` / `TrackMapView`）
  - 誤操作防止「スライドして計測終了」ロック UI（`SlideToStopView`）
  - SwiftData によるセッション永続化と履歴画面（`SessionHistoryView`）
  - StoreKit 2 サブスクリプション購入・復元 UI（`PaywallView` / `SubscriptionStore`）
  - 4言語ローカライズ（日本語 / 英語 / 中国語簡体字 / 中国語繁体字：`Localizable.xcstrings` / `InfoPlist.xcstrings`）
- **品質・CI 基盤**
  - GitHub Actions による `SnowTrackCore` テスト・SwiftLint 静的解析・iOS ビルド検証（`.github/workflows/ci.yml`）
  - Dependabot による依存関係自動更新（`.github/dependabot.yml`）

## ビルド・テスト手順

### コアパッケージのテスト
```bash
cd Packages/SnowTrackCore
swift test
```

### iOS アプリのビルド
`SnowTrackPro/SnowTrackPro.xcodeproj` を Xcode で開くか、以下のコマンドでビルドできます。
```bash
xcodebuild build \
  -project SnowTrackPro/SnowTrackPro.xcodeproj \
  -scheme SnowTrackPro \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

## 今後のロードマップ

- **Phase 2**: `CMMotionManager` / `CMAltimeter` を用いたターン数自動カウント・制動距離計測アルゴリズムの実装
- **Phase 3**: 1日のサマリー画面、1本ごとの速度・高度推移グラフ、SNS シェアカード生成
- **Phase 4**: 実地テストによるセンサー閾値・バッテリー消費チューニング
