import SwiftUI
import UIKit

/// The container app only exists to ship the keyboard extension.
/// It shows how to turn the keyboard on and gives a field to try it.
struct ContentView: View {
    @State private var sample = ""

    private let steps = [
        "Open Settings › General › Keyboard › Keyboards.",
        "Tap “Add New Keyboard…”.",
        "Under “Third-Party Keyboards”, pick “Keyboard”.",
        "Come back here, tap the field below and long-press 🌐 to switch to it."
    ]

    var body: some View {
        NavigationStack {
            Form {
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
                Section("Try it") {
                    TextField("Type here", text: $sample, axis: .vertical)
                        .accessibilityIdentifier("keyboard-sample")
                        .lineLimit(3...6)
                        .autocorrectionDisabled()
                }
                Section {
                    Text("This keyboard does not ask for Full Access and never uses the network.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Keyboard")
        }
    }
}
