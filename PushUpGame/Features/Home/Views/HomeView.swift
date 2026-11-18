//
//  HomeView.swift
//  PushUpGame
//

import SwiftData
import SwiftUI

/// App root: the alarm list plus a manual entry point into the workout.
/// Nothing here touches the camera; capture only starts once the workout
/// screen is pushed.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: AlarmRecord.listSortDescriptors) private var alarms: [AlarmRecord]

    @State private var editorPresentation: AlarmEditorPresentation?
    @State private var persistenceErrorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                alarmsSection
                workoutSection
            }
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editorPresentation = .create
                    } label: {
                        Label("Add Alarm", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .manualWorkout:
                    ManualWorkoutView()
                }
            }
            .sheet(item: $editorPresentation) { presentation in
                AlarmEditorView(alarm: presentation.alarm)
            }
            .alert(
                "Couldn't Save Changes",
                isPresented: Binding(
                    get: { persistenceErrorMessage != nil },
                    set: { if !$0 { persistenceErrorMessage = nil } }
                ),
                presenting: persistenceErrorMessage
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
        }
    }

    @ViewBuilder
    private var alarmsSection: some View {
        if alarms.isEmpty {
            Section {
                AlarmsEmptyStateView {
                    editorPresentation = .create
                }
            }
        } else {
            Section {
                ForEach(alarms) { alarm in
                    AlarmRowView(
                        alarm: alarm,
                        onEdit: { editorPresentation = .edit(alarm) },
                        onToggleEnabled: { setEnabled($0, for: alarm) }
                    )
                }
                .onDelete(perform: deleteAlarms)
            } footer: {
                SchedulingNoticeView()
            }
        }
    }

    private var workoutSection: some View {
        Section {
            NavigationLink(value: HomeRoute.manualWorkout) {
                Label("Practice Push-Ups", systemImage: "figure.strengthtraining.functional")
            }
        } header: {
            Text("Workout")
        } footer: {
            Text("Opens the camera to count push-ups without an alarm.")
        }
    }

    private func setEnabled(_ isEnabled: Bool, for alarm: AlarmRecord) {
        alarm.isEnabled = isEnabled
        saveChanges()
    }

    private func deleteAlarms(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(alarms[index])
        }
        saveChanges()
    }

    /// Saves explicitly rather than relying on autosave so failures are surfaced
    /// and the in-memory state is rolled back to match what's on disk.
    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            persistenceErrorMessage = error.localizedDescription
        }
    }
}

enum HomeRoute: Hashable {
    case manualWorkout
}

enum AlarmEditorPresentation: Identifiable {
    case create
    case edit(AlarmRecord)

    var id: String {
        switch self {
        case .create:
            return "create"
        case .edit(let alarm):
            return alarm.id.uuidString
        }
    }

    var alarm: AlarmRecord? {
        switch self {
        case .create:
            return nil
        case .edit(let alarm):
            return alarm
        }
    }
}

#Preview("With alarms") {
    if let container = makeSampleAlarmsContainer() {
        HomeView()
            .modelContainer(container)
    }
}

#Preview("Empty") {
    HomeView()
        .modelContainer(for: AlarmRecord.self, inMemory: true)
}

@MainActor
private func makeSampleAlarmsContainer() -> ModelContainer? {
    guard let container = try? AppDependencies.makeModelContainer(inMemory: true) else { return nil }
    let samples = [
        AlarmConfiguration(title: "Weekday wake-up", repeatDays: .weekdays),
        AlarmConfiguration(repeatDays: [], pushUpTarget: 20, isEnabled: false),
    ]
    for configuration in samples {
        if let record = try? AlarmRecord(configuration: configuration) {
            container.mainContext.insert(record)
        }
    }
    return container
}
