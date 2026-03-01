import SwiftUI
import SwiftData

struct RemindersListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) var lang
    @Query(sort: \Reminder.dateTime, order: .forward) private var reminders: [Reminder]

    @State private var showAddReminder = false
    @State private var reminderToEdit: Reminder?

    private var viewModel: RemindersViewModel {
        RemindersViewModel(modelContext: modelContext)
    }

    private var overdueReminders: [Reminder] {
        reminders.filter { $0.state == .overdue }
    }
    private var upcomingReminders: [Reminder] {
        reminders.filter { $0.state == .upcoming }
    }
    private var completedReminders: [Reminder] {
        reminders.filter { $0.state == .completed }
    }

    var body: some View {
        NavigationStack {
            Group {
                if reminders.isEmpty {
                    emptyState
                } else {
                    List {
                        if !overdueReminders.isEmpty {
                            Section(lang.remindersOverdue) {
                                ForEach(overdueReminders) { reminder in
                                    reminderRow(reminder)
                                }
                            }
                        }
                        if !upcomingReminders.isEmpty {
                            Section(lang.remindersUpcoming) {
                                ForEach(upcomingReminders) { reminder in
                                    reminderRow(reminder)
                                }
                            }
                        }
                        if !completedReminders.isEmpty {
                            Section(lang.remindersCompleted) {
                                ForEach(completedReminders) { reminder in
                                    reminderRow(reminder)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(lang.remindersTab)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddReminder = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddReminder) {
                AddEditReminderView(modelContext: modelContext)
            }
            .sheet(item: $reminderToEdit) { reminder in
                AddEditReminderView(reminderToEdit: reminder, modelContext: modelContext)
            }
        }
    }

    private func reminderRow(_ reminder: Reminder) -> some View {
        ReminderRowView(reminder: reminder, lang: lang)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    viewModel.deleteReminder(reminder)
                } label: {
                    Label(lang.delete, systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading) {
                if !reminder.isCompleted {
                    Button {
                        withAnimation { viewModel.markComplete(reminder) }
                    } label: {
                        Label(lang.reminderMarkComplete, systemImage: "checkmark")
                    }
                    .tint(.green)
                }
                Button {
                    reminderToEdit = reminder
                } label: {
                    Label(lang.edit, systemImage: "pencil")
                }
                .tint(.blue)
            }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.badge")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(lang.emptyRemindersTitle)
                .font(.title3.weight(.medium))
            Text(lang.emptyRemindersSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(lang.createFirstReminder) {
                showAddReminder = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
