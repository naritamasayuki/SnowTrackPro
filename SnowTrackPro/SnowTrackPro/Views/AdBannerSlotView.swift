import SwiftUI

/// 無料ユーザー向けの下部バナー領域（プロプラン購入で自動的に完全非表示）
/// 将来 GoogleMobileAds SDK を導入する際は、この View 内を GADBannerView に差し替えます。
struct AdBannerSlotView: View {
    @Environment(ProPurchaseStore.self) private var purchaseStore
    var onTapUpgrade: () -> Void

    var body: some View {
        if !purchaseStore.isProUnlocked {
            HStack(spacing: 10) {
                Image(systemName: "snowflake")
                    .font(.subheadline)
                    .foregroundStyle(.cyan)

                Text("banner.tip.pocket")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)

                Spacer(minLength: 4)

                Button("banner.hideWithPro", action: onTapUpgrade)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.yellow, in: Capsule())
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
