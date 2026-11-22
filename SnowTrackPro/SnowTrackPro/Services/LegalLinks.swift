import Foundation

/// App Store 審査（Guideline 3.1.2）で必須となる法務・サポートリンク定義
enum LegalLinks {
    /// Apple 標準エンドユーザー使用許諾契約（EULA）
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")

    /// プライバシーポリシー（GitHub Pages: docs/privacy.html）
    static let privacyPolicyURL = URL(string: "https://naritamasayuki.github.io/SnowTrackPro/privacy.html")

    /// サポートページ（GitHub Pages: docs/support.html）
    static let supportURL = URL(string: "https://naritamasayuki.github.io/SnowTrackPro/support.html")
}
