import SwiftUI

/// "NEXT VACCINATION" — a date kept per baby on this device, and a reminder a week before.
struct HealthVaccinationCard: View {
    let baby: Baby

    @Environment(AppSettings.self) private var settings
    @Environment(ThreadNavigator.self) private var navigator
    @State private var showPicker = false
    @State private var draftDate = Date()
    @State private var reminderSet = false

    var body: some View {
        let _ = settings.vaccinationVersion
        let date = settings.nextVaccinationDate(for: baby.id)

        LeonaTintCard(padding: EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)) {
            VStack(alignment: .leading, spacing: 0) {
                Text(String(localized: "vax_next").uppercased())
                    .font(.leona(11, .heavy))
                    .leonaTracking(0.1, size: 11)
                    .foregroundStyle(.tLeonaInk)

                if let date {
                    Button {
                        draftDate = date
                        showPicker = true
                    } label: {
                        Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                            .font(.leona(17, .bold))
                            .foregroundStyle(.tInk)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 7)

                    Text(caption(for: date))
                        .font(.leona(13))
                        .foregroundStyle(.tMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)

                    LeonaSmallButton(
                        title: reminderSet ? String(localized: "vax_reminder_set") : String(localized: "vax_remind"),
                        tone: .vermilion, fontSize: 13, vertical: 10, horizontal: 16, radius: 12
                    ) {
                        remind(for: date)
                    }
                    .disabled(reminderSet)
                    .opacity(reminderSet ? 0.7 : 1)
                    .padding(.top, 12)
                } else {
                    Text(String(localized: "vax_not_set"))
                        .font(.leona(17, .bold))
                        .foregroundStyle(.tInk)
                        .padding(.top, 7)
                    Text(String(localized: "vax_not_set_caption \(baby.displayName)"))
                        .font(.leona(13))
                        .foregroundStyle(.tMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                    LeonaSmallButton(title: String(localized: "vax_choose_date"), tone: .vermilion, fontSize: 13, vertical: 10, horizontal: 16, radius: 12) {
                        draftDate = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
                        showPicker = true
                    }
                    .padding(.top, 12)
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            HealthVaccinationDateSheet(
                date: $draftDate,
                canClear: date != nil,
                onSave: {
                    settings.setNextVaccinationDate(draftDate, for: baby.id)
                    reminderSet = false
                    HapticManager.success()
                },
                onClear: {
                    settings.setNextVaccinationDate(nil, for: baby.id)
                    reminderSet = false
                    NotificationManager.shared.cancelNotification(identifier: "vaccination-reminder")
                }
            )
        }
    }

    private func caption(for date: Date) -> String {
        if date < Calendar.current.startOfDay(for: Date()) {
            return String(localized: "vax_passed")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relative = formatter.localizedString(for: Calendar.current.startOfDay(for: date), relativeTo: Calendar.current.startOfDay(for: Date()))
        return String(localized: "vax_caption \(relative)")
    }

    private func remind(for date: Date) {
        Task {
            let manager = NotificationManager.shared
            if !manager.isAuthorized { await manager.checkAuthorization() }
            if !manager.isAuthorized { _ = await manager.requestAuthorization() }
            guard manager.isAuthorized else {
                navigator.flash(String(localized: "vax_reminder_denied"))
                return
            }
            await manager.scheduleVaccinationReminder(babyName: baby.displayName, date: date)
            reminderSet = true
            HapticManager.success()
            let weekBefore = Calendar.current.date(byAdding: .day, value: -7, to: date) ?? date
            navigator.flash(String(localized: "vax_reminder_toast \(weekBefore.formatted(.dateTime.day().month(.abbreviated)))"))
        }
    }
}

// MARK: - Date sheet

private struct HealthVaccinationDateSheet: View {
    @Binding var date: Date
    let canClear: Bool
    let onSave: () -> Void
    let onClear: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            InsightsSheetHeader(
                title: String(localized: "vax_next"),
                trailingTitle: String(localized: "done"),
                onLeading: { dismiss() },
                onTrailing: {
                    onSave()
                    dismiss()
                }
            )
            ScrollView {
                VStack(spacing: 12) {
                    LeonaCard(padding: EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)) {
                        DatePicker(
                            "",
                            selection: $date,
                            in: Calendar.current.startOfDay(for: Date())...,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .tint(.vermilion)
                    }
                    if canClear {
                        LeonaGroup {
                            LeonaRow(title: String(localized: "vax_clear"), destructive: true) {
                                onClear()
                                dismiss()
                            }
                        }
                    }
                }
                .padding(18)
            }
        }
        .background(Color.tCanvas.ignoresSafeArea())
        .presentationDetents([.large])
    }
}
