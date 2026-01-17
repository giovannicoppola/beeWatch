import SwiftUI

struct GoalDetailView: View {
    let goal: Goal

    @StateObject private var dataStore = DataStore.shared
    @State private var datapoints: [Datapoint] = []
    @State private var isLoading = true
    @State private var showingDataEntry = false
    @State private var showingReminders = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                quickEntrySection
                recentEntriesSection
            }
            .padding(.horizontal)
        }
        .navigationTitle(goal.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingReminders = true
                } label: {
                    Image(systemName: "bell")
                }
            }
        }
        .sheet(isPresented: $showingDataEntry) {
            DataEntryView(goal: goal)
        }
        .sheet(isPresented: $showingReminders) {
            ReminderSettingsView(goalSlug: goal.slug)
        }
        .task {
            await loadDatapoints()
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                urgencyBadge
                Spacer()
                Text(goal.timeRemaining)
                    .font(.headline)
                    .foregroundColor(urgencyColor)
            }

            if let baremin = goal.baremin, !baremin.isEmpty {
                Text("Need: \(baremin)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Rate: \(goal.formattedRate)")
                    .font(.caption)
                Spacer()
                if goal.pledge > 0 {
                    Text("$\(Int(goal.pledge))")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }

    private var quickEntrySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Entry")
                .font(.caption)
                .foregroundColor(.secondary)

            let frequentValues = dataStore.getFrequentValues(for: goal.slug)

            if frequentValues.isEmpty {
                defaultQuickEntryButtons
            } else {
                frequentValuesButtons(frequentValues)
            }

            Button {
                showingDataEntry = true
            } label: {
                Label("Custom Value", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var defaultQuickEntryButtons: some View {
        HStack(spacing: 8) {
            ForEach([1, 5, 10], id: \.self) { value in
                QuickEntryButton(value: Double(value), goalSlug: goal.slug)
            }
        }
    }

    private func frequentValuesButtons(_ values: [FrequentValue]) -> some View {
        HStack(spacing: 8) {
            ForEach(values) { frequentValue in
                QuickEntryButton(value: frequentValue.value, goalSlug: goal.slug)
            }
        }
    }

    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Entries")
                .font(.caption)
                .foregroundColor(.secondary)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if datapoints.isEmpty {
                Text("No entries yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(datapoints.prefix(5)) { datapoint in
                    DatapointRowView(datapoint: datapoint)
                }
            }
        }
    }

    private var urgencyBadge: some View {
        Text("\(goal.safebuf)d safe")
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(urgencyColor.opacity(0.2))
            .foregroundColor(urgencyColor)
            .cornerRadius(8)
    }

    private var urgencyColor: Color {
        switch goal.urgencyColor {
        case .red: return .red
        case .orange: return .orange
        case .blue: return .blue
        case .green: return .green
        }
    }

    private func loadDatapoints() async {
        isLoading = true
        do {
            datapoints = try await dataStore.fetchDatapoints(for: goal.slug)
        } catch {
            print("Failed to load datapoints: \(error)")
        }
        isLoading = false
    }
}

struct QuickEntryButton: View {
    let value: Double
    let goalSlug: String
    var onSuccess: (() -> Void)? = nil

    @StateObject private var dataStore = DataStore.shared
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var showConfirmation = false

    var body: some View {
        Button {
            showConfirmation = true
        } label: {
            if isSubmitting {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if showSuccess {
                Image(systemName: "checkmark")
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
            } else {
                Text(formattedValue)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isSubmitting)
        .confirmationDialog("Log \(formattedValue)?", isPresented: $showConfirmation, titleVisibility: .visible) {
            Button("Log \(formattedValue)") {
                submitValue()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var formattedValue: String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func submitValue() {
        isSubmitting = true

        Task {
            do {
                _ = try await dataStore.submitDatapoint(goalSlug: goalSlug, value: value)
                showSuccess = true

                try? await Task.sleep(nanoseconds: 1_500_000_000)
                showSuccess = false
            } catch {
                print("Failed to submit: \(error)")
            }
            isSubmitting = false
        }
    }
}

struct DatapointRowView: View {
    let datapoint: Datapoint

    var body: some View {
        HStack {
            Text(datapoint.formattedValue)
                .font(.headline)

            Spacer()

            VStack(alignment: .trailing) {
                Text(datapoint.timestamp.shortDateString)
                    .font(.caption2)
                if !datapoint.comment.isEmpty {
                    Text(datapoint.comment)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    GoalDetailView(goal: Goal(
        slug: "exercise",
        title: "Exercise",
        rate: 30,
        runits: "w",
        pledge: 5,
        safebuf: 2,
        losedate: Date().adding(days: 2)
    ))
}
