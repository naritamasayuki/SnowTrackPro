# Google AdMob 導入設定（v1.3.0 で本番導入済み）

v1.3.0 より Google Mobile Ads SDK（Swift Package Manager v13+）を組み込み、無料ユーザー向けの下部バナー領域（`AdBannerSlotView.swift`）で AdMob バナー広告を表示しています。
プロプラン（買い切り ¥100）を購入すると `ProPurchaseStore.isProUnlocked == true` となり、バナー広告領域は自動的に完全非表示になります。

## 本番設定値

* **AdMob アプリ ID（`GADApplicationIdentifier`）**: `ca-app-pub-4261439423960578~9967695096`
* **バナー広告ユニット ID（`SnowTrack Pro Banner`）**: `ca-app-pub-4261439423960578/1944579891`
* **DEBUG ビルド時**: Google 公式テストバナー ID（`ca-app-pub-3940256099942544/2934735716`）を自動使用
* **app-ads.txt**: `https://naritamasayuki.github.io/app-ads.txt` に公開済み
* **ATT（App Tracking Transparency）**: 初回アクティブ時に `ATTrackingManager.requestTrackingAuthorization()` を実行し、`NSUserTrackingUsageDescription` は 4 言語対応（`en`, `ja`, `zh-Hans`, `zh-Hant`）
