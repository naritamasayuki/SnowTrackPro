import Foundation
import Observation
import SnowTrackCore
import StoreKit

/// StoreKit 2 を用いた非消耗型（買い切り）プロプラン管理ストア
@MainActor
@Observable
final class ProPurchaseStore {
    private(set) var proProduct: Product?
    private(set) var isProUnlocked: Bool = false
    private(set) var isLoading: Bool = false
    private(set) var lastErrorMessage: String?
    private(set) var statusMessage: String?

    private var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = listenForTransactions()
    }

    /// 商品情報の読み込みと購入済み状態の同期を行う
    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let products = try await Product.products(for: [SaveQuotaPolicy.proUnlockProductID])
            proProduct = products.first
        } catch {
            lastErrorMessage = error.localizedDescription
            AppLogger.subscription.error("プロプラン商品の読み込みに失敗しました: \(error.localizedDescription, privacy: .public)")
        }
        // 圏外などで商品情報が取れなくても、端末に保存された購入済み状態は必ず反映する
        await refreshEntitlements()
    }

    /// プロプラン（買い切り）を購入する。購入成功時は true を返す
    @discardableResult
    func purchasePro() async -> Bool {
        guard let product = proProduct else {
            lastErrorMessage = String(localized: "pro.error.productUnavailable")
            return false
        }

        isLoading = true
        lastErrorMessage = nil
        statusMessage = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                AppLogger.subscription.info("プロプラン（買い切り）を購入しました。")
                return isProUnlocked
            case .userCancelled:
                AppLogger.subscription.info("購入がキャンセルされました。")
                return false
            case .pending:
                statusMessage = String(localized: "pro.status.pending")
                AppLogger.subscription.info("購入が承認待ちです。")
                return false
            @unknown default:
                return false
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            AppLogger.subscription.error("購入処理でエラーが発生しました: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// 購入を復元する
    func restorePurchases() async {
        isLoading = true
        lastErrorMessage = nil
        statusMessage = nil
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isProUnlocked {
                statusMessage = String(localized: "pro.status.restoreEmpty")
            }
            AppLogger.subscription.info("購入の復元を実行しました。")
        } catch {
            lastErrorMessage = error.localizedDescription
            AppLogger.subscription.error("購入の復元に失敗しました: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 現在の有効な購入状態（非消耗型）を確認する
    func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.productID == SaveQuotaPolicy.proUnlockProductID,
                   transaction.revocationDate == nil {
                    unlocked = true
                }
            } catch {
                AppLogger.subscription.warning("未検証トランザクション: \(error.localizedDescription, privacy: .public)")
            }
        }
        isProUnlocked = unlocked
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()
                    await self.refreshEntitlements()
                } catch {
                    AppLogger.subscription.error("トランザクション監視エラー: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
