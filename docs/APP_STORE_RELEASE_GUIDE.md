# SnowTrack Pro — App Store 公開手順書（Phase 1 MVP）

本ガイドは、現在のプロジェクトを **TestFlight 配信 → App Store 審査提出・公開** するための手順チェックリストです。

## 1. GitHub リポジトリ公開 & GitHub Pages 有効化（無料）

1. GitHub で新規リポジトリを作成し、ローカルの `main` ブランチをプッシュします。
   ```bash
   git remote add origin https://github.com/<あなたのユーザー名>/<リポジトリ名>.git
   git push -u origin main
   ```
2. GitHub リポジトリの **Settings → Pages** で、`Branch: main` / Folder: `/docs` を選択して保存します。
3. 数分後に公開される URL を確認します：
   - プライバシーポリシー: `https://<ユーザー名>.github.io/<リポジトリ名>/privacy.html`
   - サポートページ: `https://<ユーザー名>.github.io/<リポジトリ名>/support.html`
4. `SnowTrackPro/SnowTrackPro/Services/LegalLinks.swift` の `privacyPolicyURL` と `supportURL` を上記 URL に書き換えてコミットします。

## 2. Xcode での署名（Signing & Capabilities）設定

1. `SnowTrackPro/SnowTrackPro.xcodeproj` を Xcode で開きます。
2. ターゲット `SnowTrackPro` → **Signing & Capabilities** タブを開きます。
3. **Team** にご自身の Apple Developer アカウントを選択します。
4. **Bundle Identifier** をご自身固有の ID（例：`com.<ドメインまたは名前>.snowtrackpro`）に変更します（既に他者が使用中の ID は App Store Connect に登録できません）。
5. **+ Capability** から **In-App Purchase** と **Background Modes（Location updates）** が有効になっていることを確認します。

## 3. App Store Connect でのアプリ＆サブスクリプション登録

1. [App Store Connect](https://appstoreconnect.apple.com) → **マイ App** → **＋（新規 App）** を作成します（Bundle ID は手順 2 で設定したもの）。
2. **サブスクリプション** メニューでサブスクリプショングループ `SnowTrack Pro` を作成し、以下の 2 商品を登録します（商品 ID は `EntitlementPolicy.swift` と一致させる）：
   - 月額プラン: `com.snowtrackpro.subscription.pro.monthly`（例：¥480 / 月）
   - 年額プラン: `com.snowtrackpro.subscription.pro.yearly`（例：¥3,600 / 年）
3. **App のプライバシー** で「データ収集なし（位置情報は端末内のみ処理・外部送信なし）」として申告します。

## 4. Archive & App Store Connect へアップロード

1. Xcode 上部のビルド対象を **Any iOS Device (arm64)** に切り替えます。
2. メニューの **Product → Archive** を実行します。
3. Organizer が開いたら **Distribute App → App Store Connect → Upload** を実行します。
4. まず **TestFlight** でご自身の iPhone にインストールし、以下を確認します：
   - 位置情報権限ダイアログ・バックグラウンド計測
   - 「デモ滑走」での軌跡・速度表示・履歴保存
   - Sandbox アカウントでの Pro プラン購入・復元

## 5. App Store 審査提出時のメモ（コピペ用）

App Store Connect の **App Review 情報 → メモ** に以下を記載すると、バックグラウンド位置情報（Guideline 2.5.4）の審査がスムーズに通ります：

> 本アプリはスキー・スノーボード滑走時に iPhone をウェアのポケットに入れたまま画面オフの状態で滑走距離・速度・軌跡を記録するため、バックグラウンド位置情報（`UIBackgroundModes: location`）を使用します。
> 室内での動作確認用として、計測画面右上の「デモ滑走（Demo Run）」ボタンからサッポロテイネの模擬滑走データを再生し、自動スキー場判定・速度計測・地図軌跡・履歴保存の一連の動作をご確認いただけます。
