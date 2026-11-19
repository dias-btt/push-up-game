//
//  AlarmEditorView.swift
//  PushUpGame
//

import SwiftData
import SwiftUI

/// Create (`alarm == nil`) or edit an alarm. Works on a value-type draft so
/// Cancel discards changes without touching the persisted record.
struct AlarmEditorView: View {
    let alarm: AlarmRecord?

    @Environment(\.modelContext) private var modelContext
    @Environment(AlarmScheduleCoordinator.self) private var alarmCoordinator
    @Environment(\.dismiss) private var dismiss

    @State private var draft: AlarmConfiguration
    @State private var errorMessage: String?
    @State private var isConfirmingDelete = false

    private let original: AlarmConfiguration
    private let calendar = Calendar.current

    init(alarm: AlarmRecord?) {
        self.alarm = alarm
        let initial = alarm?.configuration ?? AlarmConfiguration()
        original = initial
        _draft = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            Form {
                timeSection
                detailsSection
                repeatSection
                if alarm != nil {
                    deleteSection
                }
            }
            .navigationTitle(alarm == nil ? "Add Alarm" : "Edit Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .interactiveDismissDisabled(draft != original)
            .alert("Couldn't Save Alarm", isPresented: isShowingError, presenting: errorMessage) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
        }
    }

    // MARK: - Sections

    private var timeSection: some View {
        Section {
            DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
        }
    }

    private var detailsSection: some View {
        Section {
            TextField("Label", text: $draft.title, prompt: Text(AlarmConfiguration.fallbackTitle))
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)

            Stepper(
                value: $draft.pushUpTarget,
                in: AlarmConfiguration.pushUpTargetRange
            ) {
                LabeledContent("Push-ups", value: "\(draft.pushUpTarget)")
            }
            .accessibilityValue("\(draft.pushUpTarget) push-ups")
        } footer: {
            if let validationError = draft.validationError {
                Text(validationError.localizedDescription)
                    .foregroundStyle(.red)
            }
        }
    }

    private var repeatSection: some View {
        Section {
            WeekdayPickerView(selection: $draft.repeatDays)
                .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
        } header: {
            Text("Repeat")
        } footer: {
            Text(draft.isOneTime ? "Rings once." : "Repeats: \(draft.repeatDays.summary(calendar: calendar))")
        }
    }

    private var deleteSection: some View {
        Section {
            Button("Delete Alarm", role: .destructive) {
                isConfirmingDelete = true
            }
            .frame(maxWidth: .infinity)
            .confirmationDialog(
                "Delete this alarm?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete Alarm", role: .destructive, action: delete)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save", action: save)
                .disabled(draft.validationError != nil)
        }
    }

    // MARK: - Bindings

    private var timeBinding: Binding<Date> {
        Binding(
            get: { draft.time.date(onSameDayAs: .now, calendar: calendar) ?? .now },
            set: { draft.time = AlarmTime(date: $0, calendar: calendar) }
        )
    }

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    // MARK: - Persistence

    /// Persists the desired state, then asks the coordinator to bring the
    /// system alarm in line. Scheduling outcomes (including a permission prompt
    /// on the first enabled alarm) show up on the alarm's row, so the editor
    /// can dismiss immediately.
    private func save() {
        do {
            let id: UUID
            if let alarm {
                try alarm.update(with: draft)
                id = alarm.id
            } else {
                let record = try AlarmRecord(configuration: draft)
                modelContext.insert(record)
                id = record.id
            }
            try modelContext.save()
            let coordinator = alarmCoordinator
            Task { await coordinator.sync(id) }
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func delete() {
        guard let alarm else { return }
        let id = alarm.id
        modelContext.delete(alarm)
        do {
            try modelContext.save()
            let coordinator = alarmCoordinator
            Task { await coordinator.sync(id) }
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
