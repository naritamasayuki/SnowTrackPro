import StoreKit
import SwiftUI

/// フリーミアム＋サブスクリプション（SnowTrack Pro）のペイウォール画面（App Store 審査 Guideline 3.1.2 準拠）
struct PaywallView: View {
    @Environment(SubscriptionStore.self) private var subscriptionStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 10) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.yellow)

                        Text("paywall.title")
                            .font(.largeTitle.bold())

                        Text("paywall.subtitle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)

                    if subscriptionStore.currentTier == .pro {
                        Label("paywall.activeBadge", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        FeatureRow(icon: "flame.fill", color: .orange, titleKey: "paywall.feature.heatmap")
                        FeatureRow(icon: "infinity", color: .green, titleKey: "paywall.feature.history")
                        FeatureRow(icon: "sparkles", color: .cyan, titleKey: "paywall.feature.proUpdates")
                    }
                    .padding()
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))

                    if subscriptionStore.products.isEmpty {
                        Text("paywall.productsUnavailable")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    } else {
                        VStack(spacing: 12) {
                            ForEach(subscriptionStore.products, id: \.id) { product in
                                Button {
                                    Task { await subscriptionStore.purchase(product) }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(product.displayName)
                                                .font(.headline)
                                            Text(product.description)
                                                .font(.caption)
                                                .opacity(0.85)
                                        }
                                        Spacer()
                                        Text(product.displayPrice)
                                            .font(.headline.bold())
                                    }
                                    .foregroundStyle(.black)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.yellow, in: RoundedRectangle(cornerRadius: 14))
                                }
                                .disabled(subscriptionStore.isLoading)
                            }
                        }
                    }

                    if let errorMessage = subscriptionStore.lastErrorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button("paywall.restore") {
                        Task { await subscriptionStore.restorePurchases() }
                    }
                    .font(.footnote.bold())
                    .foregroundStyle(.cyan)
                    .disabled(subscriptionStore.isLoading)

                    VStack(spacing: 8) {
                        Text("paywall.autoRenewNotice")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 16) {
                            if let termsURL = LegalLinks.termsOfUseURL {
                                Link("legal.termsOfUse", destination: termsURL)
                            }
                            if let privacyURL = LegalLinks.privacyPolicyURL {
                                Link("legal.privacyPolicy", destination: privacyURL)
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let titleKey: LocalizedStringKey

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)
            Text(titleKey)
                .font(.body.weight(.medium))
        }
    }
}
