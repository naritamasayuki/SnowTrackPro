# Google AdMob 導入・本番切り替えガイド（v1.1 向け）

現在の v1.0 では、外部広告 SDK を組み込まずに「データ収集なし」で最短審査通過させるため、無料ユーザー向けの下部バナー領域（`AdBannerSlotView.swift`）にゲレンデワンポイントガイドを表示しています。
プロプラン（買い切り ¥100）を購入すると `ProPurchaseStore.isProUnlocked == true` となり、バナー・広告領域は自動的に完全非表示になります。

## v1.1 で Google AdMob を有効にする手順

1. Swift Package Manager で `googleads/swift-package-manager-google-mobile-ads` を追加します。
2. `SnowTrackPro/Resources/Info.plist` に `GADApplicationIdentifier` を追加します。
3. `SnowTrackPro/Views/AdBannerSlotView.swift` の `if !purchaseStore.isProUnlocked` ブロック内を `GADBannerView` に差し替えます。
4. App Store Connect の **「アプリのプライバシー」** を AdMob 準拠（デバイス ID / 広告データ / 診断）へ更新して v1.1 を提出します。
