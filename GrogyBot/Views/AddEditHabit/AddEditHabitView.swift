import SwiftUI
import SwiftData

/// Scratchpad value type — avoids mutating the model before the user taps Save.
private struct HabitDraft {
    var name: String = ""
    var emoji: String = "✅"
    var accentColorHex: String = "#007AFF"
    var frequencyType: FrequencyType = .daily
    var selectedWeekdays: [Int] = [2, 3, 4, 5, 6]
    var allowsMultiple: Bool = false
    var dailyTarget: Int = 8
    var notificationsEnabled: Bool = false
    var notificationTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()

    enum FrequencyType: String, CaseIterable {
        case daily  = "daily"
        case custom = "custom"
    }

    var frequency: Frequency {
        switch frequencyType {
        case .daily:  return .daily
        case .custom: return .weekdays(selectedWeekdays.sorted())
        }
    }

    var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }
}

struct AddEditHabitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) var lang

    let habitToEdit: Habit?
    let existingHabitsCount: Int
    private var viewModel: HabitsViewModel

    @State private var draft = HabitDraft()
    @State private var showPermissionAlert = false

    init(habitToEdit: Habit? = nil, existingHabitsCount: Int = 0, modelContext: ModelContext) {
        self.habitToEdit = habitToEdit
        self.existingHabitsCount = existingHabitsCount
        self.viewModel = HabitsViewModel(modelContext: modelContext)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(lang.sectionNameIcon) {
                    TextField(lang.habitNamePlaceholder, text: $draft.name)
                }

                Section(lang.sectionColor) {
                    ColorPickerRow(selectedHex: $draft.accentColorHex)
                        .padding(.vertical, 4)
                }

                Section(lang.sectionSchedule) {
                    Picker(lang.repeatLabel, selection: $draft.frequencyType) {
                        ForEach(HabitDraft.FrequencyType.allCases, id: \.self) { type in
                            Text(type == .daily ? lang.everyDay : lang.specificDays).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    if draft.frequencyType == .custom {
                        WeekdayPicker(selectedDays: $draft.selectedWeekdays, accentHex: draft.accentColorHex)
                            .padding(.vertical, 4)
                    }
                }

                Section {
                    Toggle(lang.countItUp, isOn: $draft.allowsMultiple.animation())
                    if draft.allowsMultiple {
                        Stepper("\(lang.dailyGoal) \(draft.dailyTarget)", value: $draft.dailyTarget, in: 2...99)
                    }
                } header: {
                    Text(lang.sectionTracking)
                } footer: {
                    if draft.allowsMultiple {
                        Text(lang.trackingFooter)
                    }
                }

                Section {
                    Toggle(lang.sendReminder, isOn: $draft.notificationsEnabled.animation())
                    if draft.notificationsEnabled {
                        DatePicker(lang.timeLabel, selection: $draft.notificationTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text(lang.sectionReminders)
                } footer: {
                    if draft.notificationsEnabled {
                        Text(lang.remindersFooter)
                    }
                }
                .onChange(of: draft.notificationsEnabled) { _, enabled in
                    guard enabled else { return }
                    Task {
                        let granted = await NotificationManager.shared.requestAuthorization()
                        if !granted {
                            draft.notificationsEnabled = false
                            showPermissionAlert = true
                        }
                    }
                }
            }
            .navigationTitle(habitToEdit == nil ? lang.newHabitTitle : lang.editHabitTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.save) { save() }
                        .disabled(!draft.isValid)
                }
            }
            .onAppear { populateDraftIfEditing() }
            .alert(lang.notifOffTitle, isPresented: $showPermissionAlert) {
                Button(lang.openSettings) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button(lang.cancel, role: .cancel) {}
            } message: {
                Text(lang.notifOffMessage)
            }
        }
    }

    private func populateDraftIfEditing() {
        guard let habit = habitToEdit else { return }
        draft.name = habit.name
        draft.emoji = habit.emoji
        draft.accentColorHex = habit.accentColorHex
        draft.allowsMultiple = habit.allowsMultiple
        draft.dailyTarget = habit.dailyTarget
        draft.notificationsEnabled = habit.notificationsEnabled
        draft.notificationTime = habit.notificationTime
        switch habit.frequency {
        case .daily:
            draft.frequencyType = .daily
        case .weekdays(let days):
            draft.frequencyType = .custom
            draft.selectedWeekdays = days
        }
    }

    private func save() {
        if let habit = habitToEdit {
            viewModel.saveHabit(habit,
                                name: draft.name.trimmingCharacters(in: .whitespaces),
                                emoji: draft.emoji,
                                accentColorHex: draft.accentColorHex,
                                frequency: draft.frequency,
                                allowsMultiple: draft.allowsMultiple,
                                dailyTarget: draft.dailyTarget,
                                notificationsEnabled: draft.notificationsEnabled,
                                notificationTime: draft.notificationTime)
        } else {
            viewModel.addHabit(name: draft.name.trimmingCharacters(in: .whitespaces),
                               emoji: draft.emoji,
                               accentColorHex: draft.accentColorHex,
                               frequency: draft.frequency,
                               sortOrder: existingHabitsCount,
                               allowsMultiple: draft.allowsMultiple,
                               dailyTarget: draft.dailyTarget,
                               notificationsEnabled: draft.notificationsEnabled,
                               notificationTime: draft.notificationTime)
        }
        dismiss()
    }
}
