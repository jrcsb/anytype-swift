import SwiftUI

struct AIProviderSettingsView: View {
    @StateObject private var localModelSettings = LocalModelSettingsViewModel()
    
    @Injected(\.aiConfigBuilder)
    private var configBuilder: any AIConfigBuilderProtocol
    
    @State private var selectedProvider: AIProvider
    @Environment(\.dismiss) private var dismiss
    
    init() {
        let builder = Container.shared.aiConfigBuilder()
        _selectedProvider = State(initialValue: builder.preferredProvider)
    }
    
    var body: some View {
        NavigationView {
            List {
                providerSection
                localModelsSection
            }
            .navigationTitle("AI Provider Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    doneButton
                }
            }
        }
    }
    
    private var providerSection: some View {
        Section("Preferred Provider") {
            Picker("Provider", selection: $selectedProvider) {
                Text("Local (Ollama)")
                    .tag(AIProvider.ollama)
                
                if configBuilder.makeOpenAIConfig() != nil {
                    Text("OpenAI")
                        .tag(AIProvider.openai)
                }
            }
            .pickerStyle(.inline)
            
            if selectedProvider == .ollama {
                Text("Uses local models for privacy and offline support")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Uses OpenAI's services for enhanced capabilities")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var localModelsSection: some View {
        Section {
            NavigationLink {
                LocalModelSettingsView()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Manage Local Models")
                            .font(.headline)
                        Text("Download and configure Ollama models")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } footer: {
            Text("Local models provide privacy and offline support but may require more system resources.")
                .font(.caption)
        }
    }
    
    private var doneButton: some View {
        Button("Done") {
            if let configBuilder = configBuilder as? AIConfigBuilder {
                configBuilder.preferredProvider = selectedProvider
            }
            dismiss()
        }
    }
}

#Preview {
    AIProviderSettingsView()
}
