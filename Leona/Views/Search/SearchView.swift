import SwiftUI
import SwiftData

/// Full-text search over every finished entry in the thread.
struct SearchView: View {
    let baby: Baby

    @Environment(ThreadNavigator.self) private var navigator
    @Query private var allActivities: [Activity]

    @State private var query = ""
    @State private var filter: SearchFilter = .all
    @FocusState private var fieldFocused: Bool

    init(baby: Baby) {
        self.baby = baby
    }

    private enum SearchFilter: CaseIterable, Hashable {
        case all, feeds, sleep, diapers, notes

        var title: String {
            switch self {
            case .all: return String(localized: "filter_all")
            case .feeds: return String(localized: "search_filter_feeds")
            case .sleep: return String(localized: "search_filter_sleep")
            case .diapers: return String(localized: "search_filter_diapers")
            case .notes: return String(localized: "search_filter_notes")
            }
        }

        func matches(_ activity: Activity) -> Bool {
            switch self {
            case .all: return true
            case .feeds: return activity.isFeed
            case .sleep: return activity.type == .sleep
            case .diapers: return activity.type == .diaper
            case .notes: return activity.type == .note
            }
        }
    }

    private var results: [Activity] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allActivities
            .filter { $0.baby?.id == baby.id && !$0.isOngoing && filter.matches($0) }
            .filter { activity in
                guard !needle.isEmpty else { return true }
                if ThreadFormat.title(for: activity).lowercased().contains(needle) { return true }
                return (activity.noteText ?? "").lowercased().contains(needle)
            }
            .sorted { $0.sortTime > $1.sortTime }
    }

    private var countLabel: String {
        results.count == 1
            ? String(localized: "search_entry_one")
            : String(localized: "search_entries \(results.count)")
    }

    var body: some View {
        VStack(spacing: 0) {
            SubScreenHeader(title: String(localized: "search_title")) { navigator.backToThread() }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    searchField
                    filterRow
                    LeonaSectionLabel(countLabel)
                    if results.isEmpty {
                        Text(String(localized: "search_no_results"))
                            .font(.leona(14))
                            .foregroundStyle(.tMuted)
                            .padding(.top, 4)
                    }
                    ForEach(results) { activity in
                        SearchResultRow(activity: activity) {
                            navigator.go(.record(activity.id))
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .leonaScreen()
        .task {
            // Let the push animation settle before raising the keyboard.
            try? await Task.sleep(for: .milliseconds(350))
            fieldFocused = true
        }
    }

    // MARK: - Field and filters

    private var searchField: some View {
        TextField(String(localized: "search_placeholder"), text: $query)
            .font(.leona(15))
            .foregroundStyle(.tInk)
            .focused($fieldFocused)
            .submitLabel(.search)
            .autocorrectionDisabled()
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(Color.tSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.tLine, lineWidth: 1))
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(SearchFilter.allCases, id: \.self) { option in
                    LeonaPill(
                        title: option.title,
                        isOn: filter == option,
                        tone: .plum,
                        fontSize: 12,
                        vertical: 8,
                        horizontal: 14,
                        fill: false
                    ) {
                        filter = option
                    }
                }
            }
        }
    }
}

// MARK: - Result row

private struct SearchResultRow: View {
    let activity: Activity
    let action: () -> Void

    private var showsDate: Bool { !activity.sortTime.isToday }

    private var dateText: String {
        let date = activity.sortTime
        let sameYear = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
        return sameYear
            ? date.formatted(.dateTime.day().month(.abbreviated))
            : date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    var body: some View {
        Button {
            HapticManager.impact(.light)
            action()
        } label: {
            HStack(spacing: 12) {
                ColorTick(color: ThreadFormat.color(for: activity), height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ThreadFormat.title(for: activity))
                        .font(.leona(14, .bold))
                        .foregroundStyle(.tTheirsInk)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(String(localized: "search_logged_by \(activity.authorDisplayName)"))
                        .font(.leona(12))
                        .foregroundStyle(.tMuted)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(ThreadFormat.clock(activity.sortTime))
                        .font(.leona(13, .bold))
                        .foregroundStyle(.tMuted)
                    if showsDate {
                        Text(dateText)
                            .font(.leona(11, .semibold))
                            .foregroundStyle(.tMuted)
                    }
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.tTheirs)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.leonaPress)
    }
}
