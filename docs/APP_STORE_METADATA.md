# App Store Connect 登録用メタデータ & 提出チェックリスト

## 1. アプリ基本情報（App Information）

- **Bundle ID**: `com.naritamasayuki.SnowTrackPro`
- **Development Team**: `4KR684T6KV`
- **Primary Language（主言語）**: 日本語（Japanese） / 英語（English (U.S.)）
- **Category（カテゴリ）**: スポーツ（Sports） / ヘルスケア／フィットネス（Health & Fitness）
- **Version**: `1.0.0`
- **Privacy Policy URL**: `https://naritamasayuki.github.io/SnowTrackPro/privacy.html`
- **Support URL**: `https://naritamasayuki.github.io/SnowTrackPro/support.html`

---

## 2. ストア掲載テキスト（日本語 / Japanese）

- **アプリ名（30文字以内）**:
  `SnowTrack Pro - スキー・スノボ計測`
- **サブタイトル（30文字以内）**:
  `ポケットに入れたまま速度・距離・軌跡を自動記録`
- **プロモーションテキスト（170文字以内）**:
  `ウェアのポケットにiPhoneを入れたまま滑るだけ。GPSで滑走速度・距離・獲得標高差・軌跡を自動記録し、スキー場もオフラインで自動判定します。`
- **キーワード（100文字以内・カンマ区切り）**:
  `スキー,スノーボード,スノボ,GPS,トラッカー,速度,滑走記録,スキー場,ゲレンデ,マップ,ウィンタースポーツ`
- **概要（Description）**:
  ```text
  SnowTrack Pro は、ウェアのポケットに iPhone を入れたまま滑るだけで、滑走データを自動計測・記録できるスキー・スノーボード向けトラッキングアプリです。

  【主な機能】
  ■ ポケットに入れたまま自動トラッキング
  ・バックグラウンド位置情報計測により、画面オフのまま滑走を記録
  ・リフト乗車中・休憩中はGPS精度を自動調整してバッテリー消費を抑制

  ■ スキー場自動判定（オフライン対応）
  ・現在地から主要スキー場（サッポロテイネ、ルスツ、ニセコ、キロロ、白馬、野沢温泉、ウィスラー、ツェルマット等）を自動特定
  ・山間部や圏外でもローカルデータで動作

  ■ 滑走パフォーマンス＆軌跡マップ
  ・現在速度、最高速度、滑走距離、獲得標高差、滑走本数をリアルタイム表示
  ・雪面でも見やすいハイコントラスト・ダークモードUI
  ・ポケット内での誤操作を防ぐ「スライドして計測終了」ロックUI
  ・滑走ルートを MapKit 上に描画（Proプランでは速度別カラーヒートマップに対応）

  ■ プライバシー重視
  ・滑走ログ・位置情報データはすべて端末内（SwiftData）のみに保存され、外部サーバーへ送信されません。
  ```

---

## 3. Store Listing（英語 / English (U.S.)）

- **App Name (max 30 chars)**:
  `SnowTrack Pro: Ski & Board GPS`
- **Subtitle (max 30 chars)**:
  `Auto Speed, Distance & Runs`
- **Promotional Text (max 170 chars)**:
  `Keep your iPhone in your jacket pocket and ride. Automatically track ski & snowboard speed, vertical drop, runs, and trail maps with offline resort detection.`
- **Keywords (max 100 chars)**:
  `ski,snowboard,tracker,gps,speed,slopes,resort,vertical,winter,snow,map`
- **Description**:
  ```text
  SnowTrack Pro automatically records your ski and snowboard sessions while your iPhone stays safely in your jacket pocket.

  Key Features:
  - Background GPS Tracking: Automatically measures current speed, max speed, ski distance, vertical drop, and run count with smart battery optimization on lifts.
  - Offline Resort Detection: Automatically identifies major resorts worldwide without requiring cellular reception.
  - High-Contrast Glare-Proof UI: Large dark-mode telemetry built for bright snowy slopes, with a slide-to-finish lock to prevent accidental pocket taps.
  - Trail Map & Speed Heatmap: View your recorded route on MapKit, and unlock speed-colored heatmaps and unlimited session history with SnowTrack Pro.
  - Private by Design: All session logs and GPS tracks stay locally on your device.
  ```

---

## 4. App Review 審査メモ（英語推奨・コピペ用）

```text
Thank you for reviewing SnowTrack Pro.

1. Background Location Usage (Guideline 2.5.4):
SnowTrack Pro is a ski and snowboard GPS tracker designed to run while the user's iPhone stays inside their jacket pocket on the slopes. Background location updates (`UIBackgroundModes: location`) are essential to continuously record speed, distance, vertical drop, and route tracks with the screen off, and accuracy is dynamically reduced during lift rides/rest to conserve battery.

2. Testing Without Being at a Ski Resort:
On the main "Track" tab, reviewers can tap the "Demo Run" button in the top-right navigation bar to replay a simulated ski descent at Sapporo Teine. This immediately demonstrates automatic resort detection, live speed/distance/vertical-drop telemetry, MapKit trail rendering, and saving sessions to History via the "Slide to Finish Session" control.

3. Privacy & Data Storage:
No account or sign-in is required. All GPS tracks and session histories are stored strictly on-device using SwiftData and are never transmitted to external servers.

4. In-App Purchases (StoreKit 2):
Auto-renewable subscriptions (`com.snowtrackpro.subscription.pro.monthly`, `com.snowtrackpro.subscription.pro.yearly`) unlock speed-colored heatmaps on the map and unlimited session history.
```
