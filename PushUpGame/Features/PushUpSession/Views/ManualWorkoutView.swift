//
//  ManualWorkoutView.swift
//  PushUpGame
//

import SwiftUI

/// Navigation destination for a manual (non-alarm) workout.
///
/// Owns a fresh `PushUpSessionViewModel` per presentation, created on appear
/// rather than as a `@State` default: SwiftUI re-evaluates `@State` initial
/// values on every parent re-render, which would allocate throwaway capture
/// sessions. Popping this view releases the whole camera/Vision graph, and
/// re-entering builds a new one instead of reusing exhausted streams.
struct ManualWorkoutView: View {
    @State private var viewModel: PushUpSessionViewModel?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let viewModel {
                PushUpSessionView(viewModel: viewModel)
            }
        }
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            if viewModel == nil {
                viewModel = AppDependencies.makePushUpSessionViewModel()
            }
        }
    }
}
