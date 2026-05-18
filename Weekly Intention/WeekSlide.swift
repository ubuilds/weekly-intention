import SwiftUI

struct WeekSlide: View {
    let weekStart: Date
    let calendar: Calendar
    let intentionText: String

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        ZStack {
            shape
                .fill(.thinMaterial)

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(weekRangeText(for: weekStart))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Week \(weekNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                if intentionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Set intention")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    Text(intentionText)
                        .font(.largeTitle.weight(.semibold))
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                }

                Spacer()
            }
            .padding(32)
        }
        .clipShape(shape)
    }

    private var weekNumber: Int {
        calendar.component(.weekOfYear, from: weekStart)
    }

}
