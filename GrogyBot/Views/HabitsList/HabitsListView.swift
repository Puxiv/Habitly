import SwiftUI
import SwiftData

struct HabitsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) var lang
    @Query(sort: \Habit.sortOrder, order: .forward) private var habits: [Habit]

    @State private var showAddHabit = false
    @State private var habitToEdit: Habit?

    private var viewModel: HabitsViewModel {
        HabitsViewModel(modelContext: modelContext)
    }

    var body: some View {
        NavigationStack {
            Group {
                if habits.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(habits) { habit in
                            NavigationLink(destination: HistoryView(habit: habit)) {
                                HabitRowView(habit: habit, viewModel: HabitsViewModel(modelContext: modelContext))
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    HabitsViewModel(modelContext: modelContext).deleteHabit(habit)
                                } label: {
                                    Label(lang.delete, systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    habitToEdit = habit
                                } label: {
                                    Label(lang.edit, systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("GrogyBot")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddHabit = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddHabit) {
                AddEditHabitView(existingHabitsCount: habits.count, modelContext: modelContext)
            }
            .sheet(item: $habitToEdit) { habit in
                AddEditHabitView(habitToEdit: habit, existingHabitsCount: habits.count, modelContext: modelContext)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(lang.emptyHabitsTitle)
                .font(.title3.weight(.medium))
            Text(lang.emptyHabitsSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(lang.createFirstHabit) {
                showAddHabit = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    HabitsListView()
        .modelContainer(for: Habit.self, inMemory: true)
        .environment(LanguageManager.shared)
}
