//
//  WeekdayPickerView.swift
//  PushUpGame
//

import SwiftUI

/// Row of toggleable day chips. Leaving every day unselected means a one-time alarm.
struct WeekdayPickerView: View {
    @Binding var selection: WeekdaySet

    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.ordered(for: calendar), id: \.self) { weekday in
                dayButton(for: weekday)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func dayButton(for weekday: Weekday) -> some View {
        let isSelected = selection.contains(weekday)
        let index = weekday.rawValue - 1

        return Button {
            selection.toggle(weekday)
        } label: {
            Text(calendar.veryShortWeekdaySymbols[index])
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background(
                    Circle().fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(calendar.weekdaySymbols[index])
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
