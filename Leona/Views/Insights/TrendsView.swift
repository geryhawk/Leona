import SwiftUI
import SwiftData
import UIKit

/// The Trends tab of the Insights hub: a verdict, two charts, the deltas of the period,
/// and a way to hand the whole thread to the paediatrician.
struct TrendsView: View {
    let baby: Baby
    @Binding var period: TrendsPeriod

    @Environment(\.modelContext) private var modelContext
    @Environment(ThreadNavigator.self) private var navigator
    @Query private var allActivities: [Activity]
    @Query(sort: \GrowthRecord.date, order: .reverse) private var allGrowth: [GrowthRecord]
    @Query private var allHealth: [HealthRecord]

    @State private var shareItem: TrendsShareItem?

    private var activities: [Activity] { allActivities.filter { $0.baby?.id == baby.id } }
    private var growthRecords: [GrowthRecord] { allGrowth.filter { $0.baby?.id == baby.id } }
    private var healthRecords: [HealthRecord] { allHealth.filter { $0.baby?.id == baby.id } }

    var body: some View {
        let metrics = TrendsMetrics(activities: activities, growthRecords: growthRecords, baby: baby, period: period)

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                periodPills
                verdictBubble(metrics.verdict)
                milkCard(metrics)
                whyBubble(metrics.why)
                sleepCard(metrics)
                changesSection(metrics)
                HStack {
                    Spacer(minLength: 0)
                    sendButton
                }
                .padding(.top, 2)
            }
            .padding(EdgeInsets(top: 4, leading: 18, bottom: 20, trailing: 18))
        }
        .scrollIndicators(.hidden)
        .refreshable { await refreshSharedData() }
        .sheet(item: $shareItem) { item in
            TrendsShareSheet(url: item.url)
                .ignoresSafeArea()
        }
    }

    // MARK: - Period

    private var periodPills: some View {
        HStack(spacing: 7) {
            ForEach(TrendsPeriod.allCases) { candidate in
                LeonaPill(title: candidate.title, isOn: period == candidate) {
                    withAnimation(.easeOut(duration: 0.18)) { period = candidate }
                }
            }
        }
    }

    // MARK: - Leona's verdict

    private func verdictBubble(_ text: String) -> some View {
        LeonaTintCard(padding: EdgeInsets(top: 14, leading: 17, bottom: 14, trailing: 17), asBubble: true) {
            VStack(alignment: .leading, spacing: 7) {
                LeonaCardHeader()
                Text(text)
                    .font(.leona(17, .bold))
                    .leonaTracking(-0.015, size: 17)
                    .lineSpacing(3)
                    .foregroundStyle(.tInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.trailing, 34)
    }

    private func whyBubble(_ text: String) -> some View {
        Text(text)
            .font(.leona(15, .medium))
            .lineSpacing(4)
            .foregroundStyle(.tTheirsInk)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
            .background(Color.tTheirs)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.trailing, 34)
    }

    // MARK: - Charts

    private func milkCard(_ metrics: TrendsMetrics) -> some View {
        let count = metrics.current.days.count
        let items = metrics.current.days.enumerated().map { index, day in
            LeonaBarItem(
                label: metrics.barLabel(for: index),
                segments: [(value: day.milkML, color: index == count - 1 ? Color.vermilion : Color.tMine)]
            )
        }
        return LeonaCard {
            VStack(alignment: .leading, spacing: 14) {
                chartHeader(String(localized: "trends_milk_per_day"), value: metrics.milkAverageLabel)
                LeonaBarChart(items: items, barHeight: 94)
            }
        }
    }

    private func sleepCard(_ metrics: TrendsMetrics) -> some View {
        let items = metrics.current.days.enumerated().map { index, day in
            LeonaBarItem(
                label: metrics.barLabel(for: index),
                segments: [
                    (value: day.nightSeconds / 3600, color: Color.chartNight),
                    (value: day.napSeconds / 3600, color: Color.chartDay)
                ]
            )
        }
        return LeonaCard {
            VStack(alignment: .leading, spacing: 14) {
                chartHeader(String(localized: "trends_sleep_night_naps"), value: metrics.sleepAverageLabel)
                LeonaBarChart(items: items, barHeight: 82)
            }
        }
    }

    private func chartHeader(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            LeonaSectionLabel(title)
            Spacer(minLength: 8)
            Text(value)
                .font(.leona(12, .bold))
                .foregroundStyle(.tMuted)
        }
    }

    // MARK: - What changed

    private func changesSection(_ metrics: TrendsMetrics) -> some View {
        let title = period == .sevenDays
            ? String(localized: "trends_what_changed_week")
            : String(localized: "trends_what_changed_days \(period.days)")
        let rows = metrics.changes

        return VStack(alignment: .leading, spacing: 12) {
            LeonaSectionLabel(title)
                .padding(.top, 4)
            if rows.isEmpty {
                LeonaCard(padding: EdgeInsets(top: 13, leading: 15, bottom: 13, trailing: 15), radius: 16) {
                    Text(String(localized: "trends_change_none \(baby.displayName)"))
                        .font(.leona(14, .semibold))
                        .foregroundStyle(.tMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            ForEach(rows) { change in
                LeonaCard(padding: EdgeInsets(top: 13, leading: 15, bottom: 13, trailing: 15), radius: 16) {
                    HStack(spacing: 12) {
                        Text(change.delta)
                            .font(.leona(15, .heavy))
                            .foregroundStyle(change.isGain ? Color.moss : Color.vermilion)
                            .lineLimit(1)
                            .frame(minWidth: 52, alignment: .leading)
                        Text(change.what)
                            .font(.leona(14, .semibold))
                            .foregroundStyle(.tInk)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    // MARK: - Export

    private var sendButton: some View {
        Button {
            HapticManager.impact(.medium)
            if let url = ReportExporter.makeReportPDF(
                baby: baby,
                activities: activities,
                growthRecords: growthRecords,
                healthRecords: healthRecords
            ) {
                shareItem = TrendsShareItem(url: url)
            } else {
                navigator.flash(String(localized: "trends_pdf_failed"))
            }
        } label: {
            Text(String(localized: "trends_send_pdf"))
                .font(.leona(15, .bold))
                .foregroundStyle(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 18)
                .background(Color.tMine)
                .clipShape(UnevenRoundedRectangle.mineBubble)
        }
        .buttonStyle(.leonaPress)
    }

    private func refreshSharedData() async {
        guard baby.isShared else { return }
        await SyncEngine.shared.forcePullSharedBabies(context: modelContext)
    }
}

// MARK: - Share plumbing

private struct TrendsShareItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct TrendsShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
