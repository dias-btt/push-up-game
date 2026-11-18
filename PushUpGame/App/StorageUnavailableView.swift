//
//  StorageUnavailableView.swift
//  PushUpGame
//

import SwiftUI

struct StorageUnavailableView: View {
    let error: any Error

    var body: some View {
        ContentUnavailableView {
            Label("Alarms Unavailable", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Your saved alarms couldn't be loaded. Try restarting the app.\n\n\(error.localizedDescription)")
        }
    }
}
