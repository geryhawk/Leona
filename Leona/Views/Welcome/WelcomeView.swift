import SwiftUI
import SwiftData

/// First run, inside the thread: Leona asks for the name, the birthday and (for the WHO curves)
/// the sex, as chat bubbles. Also used as a full-screen cover to start a thread for another baby.
struct WelcomeView: View {
    let isAdditionalBaby: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThreadNavigator.self) private var navigator: ThreadNavigator?

    @State private var name = ""
    @State private var birthChoice: WelcomeBirthChoice?
    @State private var pickedDate = Date()
    @State private var gender: BabyGender?
    @State private var showDatePicker = false
    @FocusState private var nameFocused: Bool

    init(isAdditionalBaby: Bool) {
        self.isAdditionalBaby = isAdditionalBaby
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var hasName: Bool { !trimmedName.isEmpty }
    private var hasBirthday: Bool { birthChoice != nil }
    private var canFinish: Bool { hasName && hasBirthday }

    var body: some View {
        VStack(spacing: 0) {
            header
            conversation
            footer
        }
        .leonaScreen()
        .sheet(isPresented: $showDatePicker) {
            WelcomeDateSheet(date: $pickedDate) {
                birthChoice = .picked
                showDatePicker = false
            }
        }
        .onAppear {
            #if DEBUG
            applyDemoState()
            #endif
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 11) {
            LeonaMark(size: 34, radius: 11, fontSize: 15)
            VStack(alignment: .leading, spacing: 1) {
                Text("Leona")
                    .font(.leona(16, .bold))
                    .leonaTracking(-0.02, size: 16)
                    .foregroundStyle(.tInk)
                Text(String(localized: "welcome_setting_up"))
                    .font(.leona(12, .semibold))
                    .foregroundStyle(.vermilion)
            }
            Spacer(minLength: 0)
            if isAdditionalBaby {
                Button {
                    HapticManager.impact(.light)
                    dismiss()
                } label: {
                    Text(String(localized: "cancel"))
                        .font(.leona(14, .bold))
                        .foregroundStyle(.tMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 58)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.tLine).frame(height: 1) }
    }

    // MARK: - Conversation

    private var conversation: some View {
        GeometryReader { geo in
            let bubbleMax = (geo.size.width - 36) * 0.86
            ScrollView {
                VStack(alignment: .leading, spacing: 11) {
                    WelcomeLeonaBubble(text: String(localized: "welcome_hello"), tail: true, maxWidth: bubbleMax)
                    WelcomeLeonaBubble(text: String(localized: "welcome_two_questions"), maxWidth: bubbleMax)
                    nameRow

                    if hasName {
                        WelcomeLeonaBubble(text: String(localized: "welcome_greeting \(trimmedName)"), maxWidth: bubbleMax)
                        birthdayChips
                    }
                    if hasName, hasBirthday {
                        WelcomeLeonaBubble(text: ageLine, maxWidth: bubbleMax)
                        WelcomeLeonaBubble(text: String(localized: "welcome_gender_question"), maxWidth: bubbleMax)
                        genderChips
                    }
                }
                .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .bottom)
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .animation(.easeOut(duration: 0.22), value: hasName)
                .animation(.easeOut(duration: 0.22), value: hasBirthday)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var nameRow: some View {
        HStack(spacing: 9) {
            TextField(String(localized: "welcome_name_placeholder"), text: $name)
                .font(.leona(17, .semibold))
                .foregroundStyle(.tInk)
                .focused($nameFocused)
                .submitLabel(.done)
                .onSubmit { nameFocused = false }
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, 18)
                .frame(width: 190, height: 48)
                .background(Color.tSurface)
                .clipShape(.mineBubble)
                .overlay(UnevenRoundedRectangle.mineBubble.stroke(Color.vermilion, lineWidth: 1.5))

            Button {
                HapticManager.impact(.light)
                if hasName { nameFocused = false } else { nameFocused = true }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.vermilion)
                    .clipShape(Circle())
            }
            .buttonStyle(.leonaPress)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var birthdayChips: some View {
        HStack(spacing: 7) {
            WelcomeChip(title: String(localized: "date_today"), isOn: birthChoice == .today) {
                birthChoice = .today
            }
            WelcomeChip(title: String(localized: "date_yesterday"), isOn: birthChoice == .yesterday) {
                birthChoice = .yesterday
            }
            WelcomeChip(
                title: birthChoice == .picked ? pickedDate.formatted(date: .abbreviated, time: .omitted) : String(localized: "welcome_pick_date"),
                isOn: birthChoice == .picked
            ) {
                nameFocused = false
                showDatePicker = true
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var genderChips: some View {
        HStack(spacing: 7) {
            WelcomeChip(title: String(localized: "gender_girl"), isOn: gender == .girl) { gender = .girl }
            WelcomeChip(title: String(localized: "gender_boy"), isOn: gender == .boy) { gender = .boy }
            WelcomeChip(title: String(localized: "welcome_gender_skip"), isOn: gender == .unspecified) { gender = .unspecified }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
            LeonaPrimaryButton(
                title: canFinish ? String(localized: "welcome_cta_start") : String(localized: "welcome_cta_answer_both"),
                enabled: canFinish
            ) {
                finish()
            }
            Text(String(localized: "welcome_helper"))
                .font(.leona(13, .semibold))
                .foregroundStyle(.tMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Derived copy

    private var birthDate: Date? {
        switch birthChoice {
        case .today: return Date()
        case .yesterday: return Calendar.current.date(byAdding: .day, value: -1, to: Date())
        case .picked: return pickedDate
        case nil: return nil
        }
    }

    private var ageLine: String {
        guard let date = birthDate else { return "" }
        let days = Calendar.current.dateComponents([.day], from: date.startOfDay, to: Date().startOfDay).day ?? 0
        if days <= 0 { return String(localized: "welcome_age_today") }
        if days == 1 { return String(localized: "welcome_age_one_day") }
        if days < 14 { return String(localized: "welcome_age_days \(days)") }
        let weeks = days / 7
        if weeks < 26 { return String(localized: "welcome_age_weeks \(weeks)") }
        let months = Calendar.current.dateComponents([.month], from: date, to: Date()).month ?? 0
        return String(localized: "welcome_age_months \(months)")
    }

    // MARK: - Finish

    private func finish() {
        guard canFinish, let date = birthDate else { return }
        let baby = Baby(firstName: trimmedName, dateOfBirth: date, gender: gender ?? .unspecified)
        modelContext.insert(baby)
        try? modelContext.save()

        let settings = AppSettings.shared
        settings.activeBabyID = baby.id.uuidString
        settings.hasCompletedOnboarding = true

        Task { _ = await NotificationManager.shared.requestAuthorization() }

        HapticManager.success()
        navigator?.flash(String(localized: "welcome_thread_started \(trimmedName)"))
        if isAdditionalBaby { dismiss() }
    }

    #if DEBUG
    private func applyDemoState() {
        guard DemoDataGenerator.isDemoMode, DemoDataGenerator.requestedScreen == .onboarding else { return }
        name = "Alma"
        pickedDate = Calendar.current.date(
            byAdding: .day,
            value: -6,
            to: Calendar.current.date(byAdding: .month, value: -10, to: Date()) ?? Date()
        ) ?? Date()
        birthChoice = .picked
        gender = .girl
    }
    #endif
}

// MARK: - Pieces

private enum WelcomeBirthChoice: Equatable {
    case today, yesterday, picked
}

private struct WelcomeLeonaBubble: View {
    let text: String
    var tail = false
    let maxWidth: CGFloat

    var body: some View {
        let shape = tail
            ? AnyShape(UnevenRoundedRectangle.theirsBubble)
            : AnyShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        Text(text)
            .font(.leona(16, .medium))
            .lineSpacing(4)
            .foregroundStyle(.tInk)
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
            .background(Color.tLeonaBg)
            .clipShape(shape)
            .overlay(shape.stroke(Color.tLeonaLine, lineWidth: 1))
            .frame(maxWidth: maxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

private struct WelcomeChip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.selection()
            action()
        } label: {
            Text(title)
                .font(.leona(14, .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .foregroundStyle(isOn ? Color.white : Color.tInk)
                .padding(.vertical, 13)
                .padding(.horizontal, 16)
                .background(isOn ? Color.vermilion : Color.tSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.leonaPress)
    }
}

private struct WelcomeDateSheet: View {
    @Binding var date: Date
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "date_of_birth"))
                    .font(.leona(16, .bold))
                    .leonaTracking(-0.02, size: 16)
                    .foregroundStyle(.tInk)
                Spacer(minLength: 0)
                Button {
                    HapticManager.impact(.light)
                    onDone()
                } label: {
                    Text(String(localized: "done"))
                        .font(.leona(15, .heavy))
                        .foregroundStyle(.vermilion)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .frame(height: 54)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.tLine).frame(height: 1) }

            DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(.vermilion)
                .padding(.horizontal, 12)
                .padding(.top, 6)

            Spacer(minLength: 0)
        }
        .background(Color.tCanvas.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
