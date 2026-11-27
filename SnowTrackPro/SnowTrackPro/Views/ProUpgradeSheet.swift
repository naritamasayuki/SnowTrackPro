import StoreKit
import SwiftUI

/// プロプラン（買い切り・無制限保存）購入シート
struct ProUpgradeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProPurchaseStore.self) private var purchaseStore

    var onPurchased: (() -> Void)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer(minLength: 8)

                Image(systemName: "infinity.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.yellow)

                Text("pro.sheet.title")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text("pro.sheet.description")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    Label("pro.sheet.benefit.unlimited", systemImage: "checkmark.circle.fill")
                    Label("pro.sheet.benefit.adFree", systemImage: "checkmark.circle.fill")
                    Label("pro.sheet.benefit.charts", systemImage: "checkmark.circle.fill")
                    Label("pro.sheet.benefit.coaching", systemImage: "checkmark.circle.fill")
                    Label("pro.sheet.benefit.oneTime", systemImage: "checkmark.circle.fill")
                }
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))

                if purchaseStore.isProUnlocked {
                    Label("pro.badge.active", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .padding()
                } else if purchaseStore.proProduct == nil {
                    VStack(spacing: 10) {
                        if purchaseStore.isLoading {
                            ProgressView()
                                .tint(.yellow)
                        } else {
                            Button("pro.sheet.reloadButton") {
                                Task {
                                    await purchaseStore.load()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.yellow)
                            .foregroundStyle(.black)
                            .font(.subheadline.bold())
                        }
                    }
                    .frame(height: 54)
                } else {
                    Button {
                        Task {
                            let success = await purchaseStore.purchasePro()
                            if success {
                                onPurchased?()
                                dismiss()
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if purchaseStore.isLoading {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Text("pro.sheet.buyButton")
                                if let price = purchaseStore.proProduct?.displayPrice {
                                    Text("(\(price))")
                                }
                            }
                        }
                        .font(.headline.bold())
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.yellow, in: Capsule())
                    }
                    .disabled(purchaseStore.isLoading)
                }

                if let statusMessage = purchaseStore.statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .multilineTextAlignment(.center)
                }

                if let errorMessage = purchaseStore.lastErrorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button("paywall.restore") {
                    Task {
                        await purchaseStore.restorePurchases()
                        if purchaseStore.isProUnlocked {
                            onPurchased?()
                            dismiss()
                        }
                    }
                }
                .font(.footnote.bold())
                .foregroundStyle(.cyan)
                .disabled(purchaseStore.isLoading)

                Spacer()
            }
            .padding()
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task {
                if purchaseStore.proProduct == nil {
                    await purchaseStore.load()
                }
            }
        }
    }
}
