import SwiftUI
import UIKit

// Natywny UICalendarView opakowany w SwiftUI.
// Dla kazdego dnia z wydatkiem rysujemy customView decoration z sumarycznym
// wydatkiem (kompaktowy format: "50" / "1.2k").
struct ExpenseCalendarView: UIViewRepresentable {
    let dailyTotals: [DateComponents: Double]
    @Binding var selectedDate: DateComponents?

    func makeUIView(context: Context) -> UICalendarView {
        let cv = UICalendarView()
        cv.delegate = context.coordinator
        cv.fontDesign = .rounded
        cv.tintColor = .systemBlue
        cv.calendar = Calendar(identifier: .gregorian)
        cv.locale = Locale(identifier: "pl_PL")
        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        selection.selectedDate = selectedDate
        cv.selectionBehavior = selection
        cv.availableDateRange = DateInterval(start: .distantPast, end: Date())
        return cv
    }

    func updateUIView(_ uiView: UICalendarView, context: Context) {
        context.coordinator.parent = self

        // Reload decoration: dni z biezacych totals + te ktore byly poprzednio,
        // zeby usuniete decoracje znikaly poprawnie.
        let newKeys = Set(dailyTotals.keys)
        let toReload = newKeys.union(context.coordinator.previousKeys)
        context.coordinator.previousKeys = newKeys
        if !toReload.isEmpty {
            uiView.reloadDecorations(forDateComponents: Array(toReload), animated: false)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: ExpenseCalendarView
        var previousKeys: Set<DateComponents> = []

        init(_ parent: ExpenseCalendarView) { self.parent = parent }

        func calendarView(_ calendarView: UICalendarView,
                          decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            let key = Self.normalize(dateComponents)
            guard let total = parent.dailyTotals[key], total > 0 else { return nil }
            let text = Self.compactFormat(total)
            return .customView {
                let label = UILabel()
                label.text = text
                label.font = .systemFont(ofSize: 9, weight: .semibold)
                label.textColor = .systemRed
                label.textAlignment = .center
                label.adjustsFontSizeToFitWidth = true
                label.minimumScaleFactor = 0.7
                return label
            }
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate,
                           didSelectDate dateComponents: DateComponents?) {
            parent.selectedDate = dateComponents
        }

        static func normalize(_ dc: DateComponents) -> DateComponents {
            DateComponents(
                calendar: Calendar(identifier: .gregorian),
                year: dc.year, month: dc.month, day: dc.day
            )
        }

        static func compactFormat(_ value: Double) -> String {
            if value >= 1000 {
                return String(format: "%.1fk", value / 1000)
            }
            return String(format: "%.0f", value)
        }
    }
}
