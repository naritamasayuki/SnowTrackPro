import Foundation
import Observation
import SnowTrackCore
import StoreKit

/// StoreKit 2 を用いたフリーミアム＋サブスクリプション管理ストア
@MainActor
@Observable
final class SubscriptionStore {
    private(set) var products: [Product] = []
    private(set) var currentTier: SubscriptionTier = .free
    private(set) var isLoading: Bool = false
    private(set) var lastErrorMessage: String?

    private let policy = EntitlementPolicy()
    private var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = listenForTransactions()
    }

    func canAccess(_ feature: ProFeature) -> Bool {
        policy.canAccess(feature, tier: currentTier)
    }

    func canViewHistoryItem(at index: Int) -> Bool {
        policy.canViewHistoryItem(at: index, tier: currentTier)
    }

    /// 商品情報の読み込みと現在の契約状態更新を行う
    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetched = try await Product.products(for: EntitlementPolicy.allProductIDs)
            products = fetched.sorted { $0.price < $1.price }
            await refreshEntitlements()
        } catch {
            lastErrorMessage = error.localizedDescription
            AppLogger.subscription.error("StoreKit商品の読み込みに失敗しました: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 指定されたサブスクリプション商品の購入を実行する
    func purchase(_ product: Product) async {
        isLoading = true
        lastErrorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                AppLogger.subscription.info("購入が完了しました: \(product.id, privacy: .public)")
            case .userCancelled:
                AppLogger.subscription.info("ユーザーが購入をキャンセルしました。")
            case .pending:
                AppLogger.subscription.info("購入が承認待ち状態です。")
            @unknown default:
                break
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            AppLogger.subscription.error("購入処理でエラーが発生しました: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// App Store との同期により購入を復元する
    func restorePurchases() async {
        isLoading = true
        lastErrorMessage = nil
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            AppLogger.subscription.info("購入の復元を実行しました。")
        } catch {
            lastErrorMessage = error.localizedDescription
            AppLogger.subscription.error("購入の復元に失敗しました: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 現在の有効なトランザクションから契約ティアを更新する
    func refreshEntitlements() async {
        var hasActivePro = false
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if EntitlementPolicy.allProductIDs.contains(transaction.productID),
                   transaction.revocationDate == nil {
                    hasActivePro = true
                }
            } catch {
                AppLogger.subscription.warning("未検証トランザクションを検出しました: \(error.localizedDescription, privacy: .public)")
            }
        }
        currentTier = hasActivePro ? .pro : .free
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
                    AppLogger.subscription.error("トランザクション更新監視エラー: \(error.localizedDescription, privacy: .public)")
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
