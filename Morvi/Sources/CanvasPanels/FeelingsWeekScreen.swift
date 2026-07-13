import SwiftUI
import UIKit

struct FeelingsWeekScreen: View {
    @EnvironmentObject private var experienceStore: ExperienceContainer

    init() {
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear
        UITableView.appearance().separatorStyle = .none
    }

    var body: some View {
        let orderedFeelings = experienceStore.feelings.sorted {
            if $0.recordedAt == $1.recordedAt {
                return $0.stableKey > $1.stableKey
            }
            return $0.recordedAt > $1.recordedAt
        }

        List {
            if orderedFeelings.isEmpty {
                EmptyListArtworkView(title: "No feelings yet")
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                FeelingSummaryBar(records: orderedFeelings)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                ForEach(Array(orderedFeelings.enumerated()), id: \.element.id) { index, record in
                    FeelingRowCard(record: record, isFresh: index.isMultiple(of: 2))
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: index == orderedFeelings.count - 1 ? 10 : 24, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .background(Color.clear)
        .onAppear(perform: prepareFeelingListAppearance)
    }

    private func prepareFeelingListAppearance() {
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear
        UITableView.appearance().separatorStyle = .none
    }
}

private struct FeelingSummaryBar: View {
    @EnvironmentObject private var experienceStore: ExperienceContainer
    let records: [FeelingRecord]
    @State private var animationDecision: Bool?

    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thr", "Fri", "Sat"]

    var body: some View {
        let buckets = weeklyBuckets
        let maxCount = max(buckets.map(\.count).max() ?? 1, 1)
        let shouldAnimateBars = animationDecision ?? !experienceStore.hasShownFeelingSummaryAnimation
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Text("This week's feelings")
                    .font(TextCraft.source(24, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.leading, 20)
                    .padding(.top, 60)

                HStack(spacing: 0) {
                    ForEach(Array(buckets.enumerated()), id: \.element.id) { index, bucket in
                        FeelingDayColumn(
                            bucket: bucket,
                            dayName: dayNames[index],
                            maximumCount: maxCount,
                            shouldAnimate: shouldAnimateBars
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 116)
            }
            .frame(width: proxy.size.width, height: 401, alignment: .topLeading)
        }
        .frame(height: 401)
        .onAppear {
            let shouldAnimate = experienceStore.hasShownFeelingSummaryAnimation == false
            animationDecision = shouldAnimate
            if shouldAnimate {
                experienceStore.hasShownFeelingSummaryAnimation = true
            }
        }
    }

    private var weeklyBuckets: [FeelingDayBucket] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start
            ?? calendar.startOfDay(for: Date())
        return (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
            let entries = records.filter { calendar.isDate($0.recordedAt, inSameDayAs: day) }
            let grouped = Dictionary(grouping: entries, by: { $0.assetName })
            let dominant = grouped.max { lhs, rhs in
                if lhs.value.count == rhs.value.count {
                    let leftLatest = lhs.value.map(\.recordedAt).max() ?? .distantPast
                    let rightLatest = rhs.value.map(\.recordedAt).max() ?? .distantPast
                    return leftLatest < rightLatest
                }
                return lhs.value.count < rhs.value.count
            }?.value.first
            return FeelingDayBucket(
                day: day,
                assetName: dominant?.assetName,
                count: dominant.map { grouped[$0.assetName]?.count ?? 0 } ?? 0
            )
        }
    }

}

private struct FeelingDayColumn: View {
    let bucket: FeelingDayBucket
    let dayName: String
    let maximumCount: Int
    let shouldAnimate: Bool
    @State private var revealProgress: CGFloat = 0

    private var fillHeight: CGFloat {
        guard bucket.count > 0 else { return 0 }
        return 200 * CGFloat(bucket.count) / CGFloat(maximumCount)
    }

    var body: some View {
        VStack(spacing: 13) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 19)
                    .fill(Color(red: 1.0, green: 0.94, blue: 0.62))
                    .frame(width: 40, height: 220)
                RoundedRectangle(cornerRadius: 19)
                    .fill(Color(red: 1.0, green: 0.83, blue: 0.08))
                    .frame(width: 40, height: fillHeight * revealProgress)
                if let assetName = bucket.assetName {
                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .offset(y: -(fillHeight * revealProgress - 24))
                }
            }
            .frame(width: 48, height: 220)
            Text(dayName)
                .font(TextCraft.source(16))
                .foregroundColor(.gray)
        }
        .animation(shouldAnimate ? .easeOut(duration: 0.7).delay(0.08) : nil, value: revealProgress)
        .onAppear {
            if shouldAnimate {
                revealProgress = 1
            } else {
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    revealProgress = 1
                }
            }
        }
    }
}

private struct FeelingDayBucket: Identifiable {
    let day: Date
    let assetName: String?
    let count: Int

    var id: Date { day }
}

private struct FeelingRowCard: View {
    let record: FeelingRecord
    let isFresh: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 8) {
                Text(record.title)
                    .font(TextCraft.source(30, weight: .medium))

                Text(record.bodyText)
                    .font(TextCraft.source(15))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.72))
                    )
                    .padding(.trailing, 74)
            }
            .padding(.leading, 20)
            .padding(.trailing, 20)
            .padding(.top, 16)
            .padding(.bottom, 16)

            AvatarBadgeView(assetName: record.ownerAvatarAssetName, size: 40)
                .padding(.top, 26)
                .padding(.trailing, 20)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(record.recordedAt.formatted(date: .omitted, time: .shortened))
                .font(TextCraft.source(12))
                .foregroundColor(VisualLanguage.softInk)
                .frame(width: 94, alignment: .trailing)
                .padding(.top, 74)
                .padding(.trailing, 20)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            isFresh ? Color(red: 212 / 255, green: 255 / 255, blue: 59 / 255).opacity(0.8) : Color(red: 222 / 255, green: 251 / 255, blue: 255 / 255),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
    }
}
