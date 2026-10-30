import SwiftUI

/// Form for adding or editing one visit: precision, a start date, and an
/// optional end date.
struct VisitEditor: View {
    let title: LocalizedStringResource
    @State private var draft: VisitDraft
    let onSave: (VisitDraft) -> Void
    /// `nil` when adding.
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    init(
        title: LocalizedStringResource,
        draft: VisitDraft,
        onSave: @escaping (VisitDraft) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.title = title
        _draft = State(initialValue: draft)
        self.onSave = onSave
        self.onDelete = onDelete
    }

    private var multipleTitle: LocalizedStringResource {
        switch draft.precision {
        case .day: "Multiple Days"
        case .month: "Multiple Months"
        case .year: "Multiple Years"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Date Precision", selection: $draft.precision) {
                        Text("Day").tag(VisitDate.Precision.day)
                        Text("Month").tag(VisitDate.Precision.month)
                        Text("Year").tag(VisitDate.Precision.year)
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text("Not sure of the exact day? Choose Month or Year.")
                }

                Section {
                    VisitDatePicker(
                        label: draft.hasEnd ? "Start" : "Date",
                        parts: $draft.start,
                        precision: draft.precision
                    )
                    Toggle(isOn: $draft.hasEnd.animation()) {
                        Text(multipleTitle)
                    }
                    if draft.hasEnd {
                        VisitDatePicker(label: "End", parts: $draft.end, precision: draft.precision)
                    }
                } footer: {
                    if !draft.isValid {
                        Text("The end can't be before the start.")
                            .foregroundStyle(.red)
                    }
                }

                if let onDelete {
                    Section {
                        Button("Delete Visit", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!draft.isValid)
                }
            }
            .onChange(of: draft.hasEnd) { _, hasEnd in
                // Start the end where the start is, rather than wherever it was left.
                if hasEnd, draft.end.truncated(to: draft.precision) < draft.start.truncated(to: draft.precision) {
                    draft.end = draft.start
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// A date at the chosen precision: a date picker for days, menus for month
/// and year otherwise (the system date picker can't omit the day).
private struct VisitDatePicker: View {
    let label: LocalizedStringResource
    @Binding var parts: VisitDraft.Parts
    let precision: VisitDate.Precision

    @Environment(\.calendar) private var calendar

    private var years: [Int] {
        let latest = calendar.component(.year, from: .now) + 1
        return Array((min(1900, parts.year)...max(latest, parts.year)).reversed())
    }

    private var dayBinding: Binding<Date> {
        Binding(
            get: { parts.date(in: calendar) },
            set: { parts = VisitDraft.parts(of: $0, calendar: calendar) }
        )
    }

    var body: some View {
        switch precision {
        case .day:
            DatePicker(selection: dayBinding, displayedComponents: .date) {
                Text(label)
            }
        case .month:
            LabeledContent {
                HStack(spacing: 0) {
                    monthPicker
                    yearPicker(label: Text("\(Text(label)) Year"))
                        .labelsHidden()
                }
            } label: {
                Text(label)
            }
        case .year:
            yearPicker(label: Text(label))
        }
    }

    private var monthPicker: some View {
        Picker(selection: $parts.month) {
            ForEach(1...12, id: \.self) { month in
                Text(calendar.standaloneMonthSymbols[month - 1]).tag(month)
            }
        } label: {
            Text("\(Text(label)) Month")
        }
        .labelsHidden()
    }

    private func yearPicker(label: Text) -> some View {
        Picker(selection: $parts.year) {
            ForEach(years, id: \.self) { year in
                // Not `Text(year, format:)`, which would show "2,024".
                Text(verbatim: String(year)).tag(year)
            }
        } label: {
            label
        }
    }
}

#Preview("Add") {
    Color.clear.sheet(isPresented: .constant(true)) {
        VisitEditor(title: "Add Visit", draft: VisitDraft(today: .now), onSave: { _ in })
    }
}

#Preview("Edit month range") {
    Color.clear.sheet(isPresented: .constant(true)) {
        VisitEditor(
            title: "Edit Visit",
            draft: VisitDraft(Visit(start: VisitDate(year: 2019, month: 5), end: VisitDate(year: 2019, month: 6))),
            onSave: { _ in },
            onDelete: {}
        )
    }
}
