import SwiftUI

struct AIAgentSwarmActionButton: View {
    @Injected(\.aiAgentSwarmCoordinator)
    private var coordinator: any AIAgentSwarmCoordinatorProtocol
    
    let objectId: String
    
    var body: some View {
        Button {
            coordinator.showAgentSwarm(for: objectId)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Assistant")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text("Enhance metadata & optimize settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

// Preview provider
struct AIAgentSwarmActionButton_Previews: PreviewProvider {
    static var previews: some View {
        AIAgentSwarmActionButton(objectId: "preview-id")
            .padding()
            .previewLayout(.sizeThatFits)
            .background(Color(.systemGroupedBackground))
    }
}
