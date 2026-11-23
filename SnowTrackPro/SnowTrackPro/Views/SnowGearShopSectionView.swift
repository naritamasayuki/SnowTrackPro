import SnowTrackCore
import SwiftUI

/// スキー・スノボグッズ、リフト券、宿泊券などを Amazon で探せる購入導線セクション（PR 表記明示）
struct SnowGearShopSectionView: View {
    @Environment(\.locale) private var locale

    private let linkBuilder = AmazonAffiliateLinkBuilder()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("shop.section.title", systemImage: "bag.fill")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("PR")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.25), in: RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.orange.opacity(0.7), lineWidth: 1)
                    )
                    .foregroundStyle(.orange)

                Spacer()
            }

            Text("shop.section.disclosure")
                .font(.caption2)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(SnowGearCategory.allCases) { category in
                    if let url = linkBuilder.buildSearchURL(for: category, locale: locale) {
                        Link(destination: url) {
                            HStack(spacing: 8) {
                                Image(systemName: iconName(for: category))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.orange)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(titleKey(for: category))
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text("shop.amazon.cta")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }

    private func iconName(for category: SnowGearCategory) -> String {
        switch category {
        case .skiSnowboardGear:
            return "snowflake"
        case .liftTickets:
            return "ticket.fill"
        case .lodgingAndTravel:
            return "bed.double.fill"
        case .protectorsAndSafety:
            return "shield.checkered"
        }
    }

    private func titleKey(for category: SnowGearCategory) -> LocalizedStringKey {
        switch category {
        case .skiSnowboardGear:
            return "shop.category.gear"
        case .liftTickets:
            return "shop.category.liftTickets"
        case .lodgingAndTravel:
            return "shop.category.lodging"
        case .protectorsAndSafety:
            return "shop.category.safety"
        }
    }
}
