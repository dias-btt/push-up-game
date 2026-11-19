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
    @Environment(AlarmScheduleCoordinator.self) private var alarmCoordinator
    @Environment(AlarmChallengeRouter.self) private var challengeRouter
    @Query(sort: AlarmRecord.listSortDescriptors) private var alarms: [AlarmRecord]

    @State private var editorPresentation: AlarmEditorPresentation?
    @State private var persistenceErrorMessage: String?

    var body: some View {
        @Bindable var challengeRouter = challengeRouter
        NavigationStack(path: $challengeRouter.path) {
            List {
                AlarmPermissionSection(
                    authorization: alarmCoordinator.authorization,
                    hasEnabledAlarms: alarms.contains(where: \.isEnabled),
                    onRequestPermission: { Task { await alarmCoordinator.requestAuthorization() } }
                )
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
                case .alarmChallenge(let alarmID):
                    AlarmChallengeView(alarmID: alarmID)
                }
            }
            .onChange(of: challengeRouter.activeChallengeID) { _, alarmID in
                // An alarm challenge takes over the screen; a sheet would hide it.
                if alarmID != nil { editorPresentation = nil }
            }
            .alert("Alarm Not Found", isPresented: $challengeRouter.isShowingUnavailableAlarmNotice) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This alarm was deleted, so there's no challenge to start.")
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
                        status: alarmCoordinator.status(for: alarm),
                        isUpdating: alarmCoordinator.isUpdating(alarm.id),
                        onEdit: { editorPresentation = .edit(alarm) },
                        onToggleEnabled: { setEnabled($0, for: alarm) },
                        onRetry: { Task { await alarmCoordinator.sync(alarm.id) } }
                    )
                }
                .onDelete(perform: deleteAlarms)
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

    /// Desired state is saved first; the system alarm then follows via sync.
    private func setEnabled(_ isEnabled: Bool, for alarm: AlarmRecord) {
        alarm.setEnabled(isEnabled)
        let id = alarm.id
        guard saveChanges() else { return }
        Task { await alarmCoordinator.sync(id) }
    }

    private func deleteAlarms(at offsets: IndexSet) {
        let ids = offsets.map { alarms[$0].id }
        for index in offsets {
            modelContext.delete(alarms[index])
        }
        guard saveChanges() else { return }
        Task {
            for id in ids {
                await alarmCoordinator.sync(id)
            }
        }
    }

    /// Saves explicitly rather than relying on autosave so failures are surfaced
    /// and the in-memory state is rolled back to match what's on disk. Nothing is
    /// sent to the system unless the save succeeded.
    private func saveChanges() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            persistenceErrorMessage = error.localizedDescription
            return false
        }
    }
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
            .environment(AlarmScheduleCoordinator(service: AlarmKitService(), modelContext: container.mainContext))
            .environment(AlarmChallengeRouter(store: AlarmChallengeRequestStore(defaults: UserDefaults(suiteName: "preview") ?? .standard)))
    }
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
