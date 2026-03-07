import SwiftUI
import SwiftData

private struct ReminderDraft {
    var title: String = ""
    var emoji: String = "🔔"
    var note: String = ""
    var dateTime: Date = Date().addingTimeInterval(3600) // 1 hour from now
    var repeatType: RepeatType = .once
    var selectedWeekdays: [Int] = [2, 3, 4, 5, 6]
    var dayOfMonth: Int = 1

    enum RepeatType: String, CaseIterable {
        case once    = "once"
        case daily   = "daily"
        case weekly  = "weekly"
        case monthly = "monthly"
    }

    var repeatOption: ReminderRepeat {
        switch repeatType {
        case .once:    return .once
        case .daily:   return .daily
        case .weekly:  return .weekly(weekdays: selectedWeekdays.sorted())
        case .monthly: return .monthly(dayOfMonth: dayOfMonth)
        }
    }

    var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }
}

struct AddEditReminderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) var lang

    let reminderToEdit: Reminder?
    private var viewModel: RemindersViewModel

    @State private var draft = ReminderDraft()
    @State private var showPermissionAlert = false

    init(reminderToEdit: Reminder? = nil, modelContext: ModelContext) {
        self.reminderToEdit = reminderToEdit
        self.viewModel = RemindersViewModel(modelContext: modelContext)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(lang.sectionNameIcon) {
                    TextField(lang.reminderNamePlaceholder, text: $draft.title)
                }

                Section(lang.note) {
                    TextField(lang.reminderNotePlaceholder, text: $draft.note, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section(lang.reminderSectionWhen) {
                    DatePicker(lang.timeLabel, selection: $draft.dateTime)
                }

                Section(lang.reminderSectionRepeat) {
                    Picker(lang.repeatLabel, selection: $draft.repeatType.animation()) {
                        Text(lang.reminderOnce).tag(ReminderDraft.RepeatType.once)
                        Text(lang.reminderDaily).tag(ReminderDraft.RepeatType.daily)
                        Text(lang.reminderWeekly).tag(ReminderDraft.RepeatType.weekly)
                        Text(lang.reminderMonthly).tag(ReminderDraft.RepeatType.monthly)
                    }

                    if draft.repeatType == .weekly {
                        WeekdayPicker(selectedDays: $draft.selectedWeekdays, accentHex: "#007AFF")
                            .padding(.vertical, 4)
                    }

                    if draft.repeatType == .monthly {
                        Stepper("\(lang.reminderDayOfMonth): \(draft.dayOfMonth)", value: $draft.dayOfMonth, in: 1...31)
                    }
                }
            }
            .navigationTitle(reminderToEdit == nil ? lang.newReminderTitle : lang.editReminderTitle)
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
        guard let reminder = reminderToEdit else { return }
        draft.title = reminder.title
        draft.emoji = reminder.emoji
        draft.note = reminder.note
        draft.dateTime = reminder.dateTime
        switch reminder.repeatOption {
        case .once:
            draft.repeatType = .once
        case .daily:
            draft.repeatType = .daily
        case .weekly(let days):
            draft.repeatType = .weekly
            draft.selectedWeekdays = days
        case .monthly(let day):
            draft.repeatType = .monthly
            draft.dayOfMonth = day
        }
    }

    private func save() {
        Task {
            let granted = await NotificationManager.shared.requestAuthorization()
            if !granted {
                showPermissionAlert = true
                return
            }

            if let reminder = reminderToEdit {
                viewModel.saveReminder(reminder,
                                       title: draft.title.trimmingCharacters(in: .whitespaces),
                                       emoji: draft.emoji,
                                       note: draft.note,
                                       dateTime: draft.dateTime,
                                       repeatOption: draft.repeatOption)
            } else {
                viewModel.addReminder(title: draft.title.trimmingCharacters(in: .whitespaces),
                                      emoji: draft.emoji,
                                      note: draft.note,
                                      dateTime: draft.dateTime,
                                      repeatOption: draft.repeatOption)
            }
            dismiss()
        }
    }
}
