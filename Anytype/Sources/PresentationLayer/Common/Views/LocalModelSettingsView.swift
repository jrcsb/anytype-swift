import SwiftUI

struct LocalModelSettingsView: View {
    @StateObject private var viewModel = LocalModelSettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                modelStatusSection
                modelRequirementsSection
                
                if let error = viewModel.error {
                    errorSection(error)
                }
            }
            .navigationTitle("Local AI Models")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    closeButton
                }
            }
        }
    }
    
    private var modelStatusSection: some View {
        Section("Available Models") {
            ForEach(Array(viewModel.modelStatuses.keys.sorted()), id: \.self) { model in
                ModelRowView(
                    model: model,
                    isSelected: model == viewModel.selectedModel,
                    status: viewModel.getStatusDescription(for: model),
                    statusColor: viewModel.getStatusColor(for: model),
                    description: viewModel.getModelDescription(model)
                ) {
                    Task {
                        await viewModel.selectModel(model)
                    }
                }
            }
        }
    }
    
    private var modelRequirementsSection: some View {
        Section("System Requirements") {
            ForEach(Array(viewModel.modelStatuses.keys.sorted()), id: \.self) { model in
                VStack(alignment: .leading, spacing: 4) {
                    Text(model)
                        .font(.headline)
                    Text(viewModel.getRequirements(for: model))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private func errorSection(_ error: Error) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Error")
                    .font(.headline)
                    .foregroundColor(.red)
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
    }
    
    private var refreshButton: some View {
        Button {
            Task {
                await viewModel.refreshModelStatuses()
            }
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(viewModel.isLoading)
    }
    
    private var closeButton: some View {
        Button("Close") {
            dismiss()
        }
    }
}

struct ModelRowView: View {
    let model: String
    let isSelected: Bool
    let status: String
    let statusColor: Color
    let description: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(model)
                            .font(.headline)
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(status)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LocalModelSettingsView()
}
