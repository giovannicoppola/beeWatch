import SwiftUI

struct DataEntryView: View {
    let goalSlug: String

    private var goal: Goal? {
        dataStore.goals.first { $0.slug == goalSlug }
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataStore = DataStore.shared

    @State private var valueString = ""
    @State private var comment = UserSettings.shared.defaultComment
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    valueSection
                    numberPad
                    commentSection
                    submitButton
                }
                .padding()
            }
            .navigationTitle("Add Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var valueSection: some View {
        VStack(spacing: 4) {
            Text(goal?.title ?? goalSlug)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(valueString.isEmpty ? "0" : valueString)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)
        }
    }

    private var numberPad: some View {
        VStack(spacing: 8) {
            ForEach(0..<3) { row in
                HStack(spacing: 8) {
                    ForEach(1...3, id: \.self) { col in
                        let number = row * 3 + col
                        NumberButton(value: "\(number)") {
                            appendDigit("\(number)")
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                NumberButton(value: ".") {
                    appendDecimal()
                }

                NumberButton(value: "0") {
                    appendDigit("0")
                }

                NumberButton(value: "←", isDestructive: true) {
                    deleteDigit()
                }
            }
        }
    }

    private var commentSection: some View {
        TextField("Comment", text: $comment)
            .textFieldStyle(.plain)
            .padding(8)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
    }

    private var submitButton: some View {
        Button {
            submitData()
        } label: {
            if isSubmitting {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Text("Submit")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
        .disabled(valueString.isEmpty || isSubmitting)
    }

    private func appendDigit(_ digit: String) {
        if valueString.count < 10 {
            valueString += digit
        }
    }

    private func appendDecimal() {
        if !valueString.contains(".") {
            if valueString.isEmpty {
                valueString = "0."
            } else {
                valueString += "."
            }
        }
    }

    private func deleteDigit() {
        if !valueString.isEmpty {
            valueString.removeLast()
        }
    }

    private func submitData() {
        guard let value = Double(valueString) else {
            errorMessage = "Invalid number"
            showError = true
            return
        }

        isSubmitting = true

        Task {
            do {
                _ = try await dataStore.submitDatapoint(
                    goalSlug: goalSlug,
                    value: value,
                    comment: comment
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSubmitting = false
        }
    }
}

struct NumberButton: View {
    let value: String
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(.bordered)
        .tint(isDestructive ? .red : nil)
    }
}

#Preview {
    DataEntryView(goalSlug: "exercise")
}
