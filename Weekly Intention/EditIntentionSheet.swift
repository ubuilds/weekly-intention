import SwiftUI
import Foundation

struct EditIntentionSheet: View {
    let weekStart: Date
    let calendar: Calendar

    @Binding var text: String
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Text(rangeTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextEditor(text: $text)
                    .font(.title3)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))

                Spacer()
            }
            .padding()
            .navigationTitle("Weekly Intention")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Persist to SwiftData via the parent callback.
                        onSave()

                        dismiss()
                    }
                }
            }
        }
    }

    private var rangeTitle: String {
        weekRangeText(for: weekStart)
    }
}
