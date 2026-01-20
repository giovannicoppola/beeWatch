import SwiftUI

struct GoalDetailView: View {
    let goalSlug: String

    // Look up the current goal from the store to get latest data
    private var goal: Goal? {
        dataStore.goals.first { $0.slug == goalSlug }
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataStore = DataStore.shared
    @State private var datapoints: [Datapoint] = []
    @State private var isLoading = true
    @State private var showingDataEntry = false
    @State private var showingReminders = false
    @State private var showingSuccess = false

    // Init that takes a Goal for backwards compatibility
    init(goal: Goal) {
        self.goalSlug = goal.slug
    }

    var body: some View {
        Group {
            if let goal = goal {
                ZStack {
                    ScrollView {
                        VStack(spacing: 16) {
                            headerSection(goal)
                            quickEntrySection(goal)
                            recentEntriesSection
                        }
                        .padding(.horizontal)
                    }

                    if showingSuccess {
                        successOverlay
                    }
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
                    DataEntryView(goalSlug: goalSlug)
                }
                .sheet(isPresented: $showingReminders) {
                    ReminderSettingsView(goalSlug: goalSlug)
                }
            } else {
                ProgressView("Loading...")
            }
        }
        .task {
            await loadDatapoints()
        }
    }

    private func headerSection(_ goal: Goal) -> some View {
        VStack(spacing: 8) {
            HStack {
                urgencyBadge(goal)
                Spacer()
                Text(goal.timeRemaining)
                    .font(.headline)
                    .foregroundColor(urgencyColor(goal))
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

    private func quickEntrySection(_ goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Entry")
                .font(.caption)
                .foregroundColor(.secondary)

            let frequentValues = dataStore.getFrequentValues(for: goalSlug)

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
                QuickEntryButton(value: Double(value), goalSlug: goalSlug, onSuccess: handleEntrySuccess)
            }
        }
    }

    private func frequentValuesButtons(_ values: [FrequentValue]) -> some View {
        HStack(spacing: 8) {
            ForEach(values) { frequentValue in
                QuickEntryButton(value: frequentValue.value, goalSlug: goalSlug, onSuccess: handleEntrySuccess)
            }
        }
    }

    private var successOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            Text("Logged!")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    private func handleEntrySuccess() {
        showingSuccess = true
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            await MainActor.run {
                dismiss()
            }
            await dataStore.refreshGoals()
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

    private func urgencyBadge(_ goal: Goal) -> some View {
        Text("\(goal.safebuf)d safe")
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(urgencyColor(goal).opacity(0.2))
            .foregroundColor(urgencyColor(goal))
            .cornerRadius(8)
    }

    private func urgencyColor(_ goal: Goal) -> Color {
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
            datapoints = try await dataStore.fetchDatapoints(for: goalSlug)
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
    @State private var showConfirmation = false

    var body: some View {
        Button {
            showConfirmation = true
        } label: {
            if isSubmitting {
                ProgressView()
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
                await MainActor.run {
                    isSubmitting = false
                    onSuccess?()
                }
            } catch {
                print("Failed to submit: \(error)")
                await MainActor.run {
                    isSubmitting = false
                }
            }
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
