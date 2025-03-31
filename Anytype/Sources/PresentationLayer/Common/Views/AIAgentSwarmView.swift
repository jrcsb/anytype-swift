import SwiftUI

struct AIAgentSwarmView: View {
    @StateObject private var viewModel = AIAgentSwarmViewModel()
    let objectId: String
    
    var body: some View {
        VStack(spacing: 16) {
            if viewModel.autoConfigurationComplete {
                completionBanner
            }
            
            // Queue status
            queueStatusSection
            
            // Agent status section
            statusSection
            
            // Action buttons
            actionButtons
            
            // Error display
            if let error = viewModel.error {
                errorView(error)
            }
        }
        .padding()
    }
    
    private var queueStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Queue Status")
                .font(.headline)
            
            Text(viewModel.getQueueStatusDescription())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.secondarySystemBackground))
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI Agents Status")
                .font(.headline)
            
            ForEach(Array(viewModel.agentStatuses.keys), id: \.self) { agentId in
                HStack {
                    statusIndicator(for: viewModel.agentStatuses[agentId])
                    Text(viewModel.getAgentStatusDescription(for: agentId))
                        .font(.subheadline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var completionBanner: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Auto-configuration complete!")
                .font(.subheadline)
                .foregroundColor(.green)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green.opacity(0.1))
        )
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await viewModel.autoConfigureObject(
                        objectId: objectId,
                        content: "" // In practice, this would come from the object's content
                    )
                }
            } label: {
                Label("Auto Configure", systemImage: "wand.and.stars.inverse")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .disabled(viewModel.isProcessing)
            Button {
                Task {
                    await viewModel.enrichObjectMetadata(objectId: objectId)
                }
            } label: {
                Label("Enrich Metadata", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isProcessing)
            
            Button {
                Task {
                    await viewModel.optimizeObjectConfiguration(objectId: objectId)
                }
            } label: {
                Label("Optimize Configuration", systemImage: "gearshape.2")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isProcessing)
            
            if viewModel.isProcessing {
                Button(role: .destructive) {
                    Task {
                        await viewModel.cancelAllTasks()
                    }
                } label: {
                    Label("Cancel All Tasks", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private func statusIndicator(for status: AIAgentStatus?) -> some View {
        Circle()
            .fill(statusColor(for: status))
            .frame(width: 8, height: 8)
    }
    
    private func statusColor(for status: AIAgentStatus?) -> Color {
        guard let status = status else { return .gray }
        
        switch status {
        case .idle:
            return .green
        case .processing:
            return .blue
        case .error:
            return .red
        }
    }
    
    private func errorView(_ error: Error) -> some View {
        Text(error.localizedDescription)
            .foregroundColor(.red)
            .font(.callout)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.1))
            )
    }
}

#Preview {
    AIAgentSwarmView(objectId: "preview-object-id")
        .padding()
}
