import SwiftUI
import UIKit

struct ContentView: View {
    @State private var sample = ""

    private let steps = [
        "Open Settings › General › Keyboard › Keyboards.",
        "Tap “Add New Keyboard”.",
        "Under “Third-Party Keyboards”, choose “Keyboard Host”.",
        "Return here, tap the test field, then use the globe to select Keyboard Host."
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Try the keyboard") {
                    TextField("Tap a hex key", text: $sample, axis: .vertical)
                        .accessibilityIdentifier("keyboard-sample")
                        .lineLimit(3...6)
                        .autocorrectionDisabled()
                }
                Section("Swipe to edit") {
                    Label("Delete · keep dragging to repeat", systemImage: "arrow.left")
                    Label("Space", systemImage: "arrow.right")
                    Label("Capitalize the starting letter", systemImage: "arrow.up")
                    Label("Return", systemImage: "arrow.down")
                }
                Section("More keys") {
                    Text("Tap 123 for numbers and symbols. Hold 123 to choose a letter order.")
                    Text("Hold the period key, slide to a punctuation mark, then release. The popup also includes a globe when keyboard switching is needed.")
                }
                Section("Enable the keyboard") {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(index + 1).").bold()
                            Text(step)
                        }
                    }
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                Section {
                    Text("The keyboard works without Full Access and never sends typed text over the network.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Hex 7×4")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
