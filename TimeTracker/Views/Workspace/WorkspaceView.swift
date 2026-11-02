import SwiftUI

enum NotePromptDefaults {
    static let systemPrompt = """
    Schreibe kurze, sachliche Statusnotizen auf Deutsch fuer eine Zeiterfassung.
    Nutze den Projekt-Scope als Kontext und vorhandene Notizen als Hinweis darauf, woran gerade gearbeitet wurde.
    Nutze @memory, um bereits geschriebene AI-Notizen und verdichtete Historie zu beruecksichtigen.
    Die Ausgabe muss vollstaendig Deutsch sein; uebersetze englische Eingaben ins Deutsche.
    Schreibe in der Vergangenheit, ohne Spekulationen, ohne neue Aufgaben und ohne Meta-Kommentare.
    Wenn der konkrete Fortschritt nicht eindeutig ist, formuliere allgemein, aber hilfreich.
    Ausgabe: entweder ein kurzer Absatz mit 1-2 Saetzen oder 1-2 knappe Bullet Points.
    """
    static let memory = ""
}

private enum LLMProviderAuthMode {
    case apiKey
    case connect
    case local
}

private enum LLMProvider: String, CaseIterable, Identifiable {
    case openRouter
    case inceptionLabs
    case google
    case anthropic
    case openAI
    case kimi
    case xAI
    case deepSeek
    case lmStudio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openRouter:
            return "OpenRouter"
        case .inceptionLabs:
            return "Inception Labs"
        case .google:
            return "Google"
        case .anthropic:
            return "Anthropic"
        case .openAI:
            return "OpenAI"
        case .kimi:
            return "Kimi"
        case .xAI:
            return "xAI"
        case .deepSeek:
            return "DeepSeek"
        case .lmStudio:
            return "LM Studio / Local LLMs"
        }
    }

    var authMode: LLMProviderAuthMode {
        switch self {
        case .lmStudio:
            return .local
        default:
            return .apiKey
        }
    }

    var actionTitle: String {
        switch authMode {
        case .apiKey:
            return "API Key"
        case .connect:
            return "Connect"
        case .local:
            return "Configure"
        }
    }
}

private enum LLMProviderPreferenceKeys {
    static let selectedProvider = "llm_provider_selected"
    static let connectedPrefix = "llm_provider_connected_"
    static let credentialPrefix = "llm_provider_credential_"
    static let discoveredModelsPrefix = "llm_discovered_models_"
    static let selectedSummarizerModel = "llm_summarizer_model_selected"
    static let systemPrompt = "llm_note_system_prompt"
    static let memory = "llm_note_memory"
}

private struct SummarizerModel: Identifiable, Equatable, Codable {
    let providerRawValue: String
    let id: String
    let title: String
    let subtitle: String

    var identity: String { "\(providerRawValue)|\(id)" }
    var provider: LLMProvider? { LLMProvider(rawValue: providerRawValue) }

    static func models(for provider: LLMProvider) -> [SummarizerModel] {
        switch provider {
        case .openRouter:
            return [
                .init(provider: provider, id: "openrouter/auto", title: "Auto Router", subtitle: "Let OpenRouter pick the best available summarizer."),
                .init(provider: provider, id: "anthropic/claude-sonnet", title: "Claude Sonnet", subtitle: "Balanced quality for clean work summaries."),
                .init(provider: provider, id: "google/gemini-flash", title: "Gemini Flash", subtitle: "Fast summaries for short notes."),
                .init(provider: provider, id: "deepseek/deepseek-chat", title: "DeepSeek Chat", subtitle: "Cost-aware general summaries.")
            ]
        case .inceptionLabs:
            return [
                .init(provider: provider, id: "inception/default", title: "Inception Default", subtitle: "Use the default Inception Labs summarizer model."),
                .init(provider: provider, id: "inception/fast", title: "Fast", subtitle: "Shorter, quicker note suggestions."),
                .init(provider: provider, id: "inception/reasoning", title: "Reasoning", subtitle: "More deliberate summaries for broad project scopes.")
            ]
        case .google:
            return [
                .init(provider: provider, id: "gemini-flash", title: "Gemini Flash", subtitle: "Fast and light for everyday summaries."),
                .init(provider: provider, id: "gemini-pro", title: "Gemini Pro", subtitle: "Higher quality for longer project notes.")
            ]
        case .anthropic:
            return [
                .init(provider: provider, id: "claude-sonnet", title: "Claude Sonnet", subtitle: "Best default for polished, concise notes."),
                .init(provider: provider, id: "claude-haiku", title: "Claude Haiku", subtitle: "Lower-latency note generation.")
            ]
        case .openAI:
            return [
                .init(provider: provider, id: "gpt-4.1-mini", title: "GPT-4.1 Mini", subtitle: "Fast default for concise note generation."),
                .init(provider: provider, id: "gpt-4.1", title: "GPT-4.1", subtitle: "Higher quality notes for detailed scopes."),
                .init(provider: provider, id: "gpt-4o-mini", title: "GPT-4o Mini", subtitle: "Lightweight summaries for everyday tracking.")
            ]
        case .kimi:
            return [
                .init(provider: provider, id: "kimi/default", title: "Kimi Default", subtitle: "Use the default Kimi coding model."),
                .init(provider: provider, id: "kimi/k2", title: "Kimi K2", subtitle: "Stronger summaries for technical project notes."),
                .init(provider: provider, id: "moonshot/long-context", title: "Long Context", subtitle: "Useful when project scope is detailed.")
            ]
        case .xAI:
            return [
                .init(provider: provider, id: "xai/default", title: "xAI Default", subtitle: "Use your connected xAI default model."),
                .init(provider: provider, id: "grok/fast", title: "Grok Fast", subtitle: "Quick summaries for short work sessions."),
                .init(provider: provider, id: "grok/reasoning", title: "Grok Reasoning", subtitle: "More deliberate summaries.")
            ]
        case .deepSeek:
            return [
                .init(provider: provider, id: "deepseek-chat", title: "DeepSeek Chat", subtitle: "General purpose summary generation."),
                .init(provider: provider, id: "deepseek-reasoner", title: "DeepSeek Reasoner", subtitle: "Better for complex project scopes.")
            ]
        case .lmStudio:
            return [
                .init(provider: provider, id: "lmstudio/loaded", title: "Loaded Model", subtitle: "Use whichever model is currently loaded in LM Studio."),
                .init(provider: provider, id: "lmstudio/fast", title: "Local Fast", subtitle: "Prefer a smaller local summarizer model."),
                .init(provider: provider, id: "lmstudio/quality", title: "Local Quality", subtitle: "Prefer your higher quality local model.")
            ]
        }
    }

    init(provider: LLMProvider, id: String, title: String, subtitle: String) {
        self.providerRawValue = provider.rawValue
        self.id = id
        self.title = title
        self.subtitle = subtitle
    }

    init(providerRawValue: String, id: String, title: String, subtitle: String) {
        self.providerRawValue = providerRawValue
        self.id = id
        self.title = title
        self.subtitle = subtitle
    }
}

struct SettingsView: View {
    @StateObject private var viewModel = WorkspaceViewModel()
    @State private var editingTarget: ProjectEditorTarget?
    @State private var configuringLLMProvider: LLMProvider?
    @State private var selectedLLMProviderRawValue = LLMProvider.openRouter.rawValue
    @State private var selectedSummarizerModelIdentity = ""
    @State private var showingModelsCard = false
    @State private var showingSystemPromptCard = false
    @State private var showingMemoryCard = false
    @State private var systemPromptText = ""
    @State private var memorySnapshot = ""
    @State private var memoryLimitText = ""
    @State private var isRefreshingModels = false
    @State private var modelDiscoveryMessage: String?
    @State private var settingsRefreshID = UUID()
    @AppStorage(DisplayPreferenceKeys.dateFormat) private var dateFormatRawValue = DateDisplayFormat.dayMonthYear.rawValue
    @AppStorage(DisplayPreferenceKeys.timeFormat) private var timeFormatRawValue = TimeDisplayFormat.twentyFourHour.rawValue

    var body: some View {
        ZStack {
            AppTheme.primary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spacingLG) {
                    Text("Settings")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    formattingSection
                    llmProviderSection
                    projectsSection
                }
                .padding(AppTheme.spacingLG)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .sheet(item: $editingTarget) { target in
            ProjectEditorSheet(project: target.project) { project in
                viewModel.saveProject(project)
            }
        }
        .sheet(item: $configuringLLMProvider) { provider in
            LLMProviderConfigSheet(
                provider: provider,
                isSelected: selectedLLMProvider == provider,
                savedCredential: savedCredential(for: provider),
                onSelect: {
                    selectLLMProvider(provider)
                },
                onSaveCredential: { value in
                    saveCredential(value, for: provider)
                    selectLLMProvider(provider)
                    configuringLLMProvider = nil
                    refreshModels(for: provider)
                },
                onConnect: {
                    setConnected(true, for: provider)
                    selectLLMProvider(provider)
                    configuringLLMProvider = nil
                },
                onCancel: {
                    configuringLLMProvider = nil
                }
            )
            .frame(minWidth: 420, minHeight: 320)
        }
        .onAppear {
            viewModel.loadData()
            loadLLMSettings()
        }
        .onReceive(NotificationCenter.default.publisher(for: .workspaceDidChange)) { _ in
            viewModel.loadData()
        }
        .alert("Settings", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var llmProviderSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            Text("LLM Provider")
                .font(.title3.weight(.bold))
                .foregroundColor(AppTheme.textPrimary)

            VStack(spacing: 0) {
                ForEach(LLMProvider.allCases) { provider in
                    llmProviderRow(provider)
                }
            }
            .id(settingsRefreshID)
            .background(AppTheme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))

            modelsButton

            systemPromptButton

            if showingSystemPromptCard {
                systemPromptCard
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            memoryButton
        }
        .padding(AppTheme.spacingLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
    }

    private func llmProviderRow(_ provider: LLMProvider) -> some View {
        let isSelected = selectedLLMProvider == provider

        return HStack(spacing: AppTheme.spacingMD) {
            LLMProviderGlyph(provider: provider)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: AppTheme.spacingSM) {
                    Text(provider.title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)

                    if isSelected {
                        Text("Selected")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                }

                Text(providerDescription(for: provider))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: AppTheme.spacingLG)

            Button {
                configuringLLMProvider = provider
            } label: {
                HStack(spacing: AppTheme.spacingSM) {
                    Image(systemName: providerActionIcon(for: provider))
                        .font(.system(size: 14, weight: .bold))
                    Text(providerActionTitle(for: provider))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundColor(AppTheme.textPrimary)
                .padding(.horizontal, AppTheme.spacingMD)
                .frame(height: 38)
                .background(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppTheme.spacingMD)
        .padding(.vertical, AppTheme.spacingMD)
        .background(isSelected ? AppTheme.surfaceAlt.opacity(0.45) : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
                .padding(.leading, 64)
        }
    }

    private var modelsButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                showingModelsCard.toggle()
            }
            if showingModelsCard {
                refreshConnectedProviderModels()
            }
        } label: {
            HStack(spacing: AppTheme.spacingMD) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Models")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    Text(selectedSummarizerModelTitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if isRefreshingModels {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 30, height: 30)
                } else {
                    Image(systemName: showingModelsCard ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(width: 30, height: 30)
                }
            }
            .padding(.horizontal, AppTheme.spacingMD)
            .padding(.vertical, AppTheme.spacingSM)
            .background(AppTheme.surfaceMuted)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, AppTheme.spacingMD)
        .popover(isPresented: $showingModelsCard, arrowEdge: .trailing) {
            modelsCard
                .frame(width: 560, height: 520)
                .background(AppTheme.primary)
        }
    }

    private var modelsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            HStack {
                Text("Summarizer Model")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Button {
                    refreshConnectedProviderModels(force: true)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(isRefreshingModels)
            }

            if connectedSummarizerModels.isEmpty {
                Text("Connect a provider first. When an API key or local endpoint is saved, TimeTracker checks that provider for available models and shows them here.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(AppTheme.spacingMD)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(connectedSummarizerModels) { model in
                            summarizerModelRow(model)
                        }
                    }
                    .background(AppTheme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
                }
            }

            if let modelDiscoveryMessage {
                Text(modelDiscoveryMessage)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .padding(AppTheme.spacingMD)
        .background(AppTheme.surfaceAlt.opacity(0.42))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
        .padding(AppTheme.spacingSM)
    }

    private var systemPromptButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                showingSystemPromptCard.toggle()
            }
        } label: {
            HStack(spacing: AppTheme.spacingMD) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text("System Prompt")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    Text(systemPromptPreview)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: showingSystemPromptCard ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(width: 30, height: 30)
            }
            .padding(.horizontal, AppTheme.spacingMD)
            .padding(.vertical, AppTheme.spacingSM)
            .background(AppTheme.surfaceMuted)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, AppTheme.spacingXS)
    }

    private var systemPromptCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            Text("Tell the AI how to write notes from the project scope. This gets added before the project-specific scope and existing note.")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)

            TextEditor(text: $systemPromptText)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(AppTheme.spacingSM)
                .frame(minHeight: 110)
                .background(AppTheme.surfaceMuted)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))

            HStack(spacing: AppTheme.spacingXS) {
                Text("Use")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)

                Button {
                    insertMemoryToken()
                } label: {
                    Text("@memory")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.pink)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.pink.opacity(0.14))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Text("where the prompt should receive AI-owned memory.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
            }

            HStack {
                Button {
                    resetSystemPrompt()
                } label: {
                    Text("Default")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                        .frame(height: 32)
                        .padding(.horizontal, AppTheme.spacingMD)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    saveSystemPrompt()
                } label: {
                    Text("Save")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.primary)
                        .frame(height: 32)
                        .padding(.horizontal, AppTheme.spacingMD)
                        .background(AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppTheme.spacingMD)
        .background(AppTheme.surfaceAlt.opacity(0.42))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
    }

    private var memoryButton: some View {
        Button {
            refreshMemorySnapshot()
            showingMemoryCard.toggle()
        } label: {
            HStack(spacing: AppTheme.spacingMD) {
                Image(systemName: "brain")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Memory")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    Text(memoryPreview)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "rectangle.and.text.magnifyingglass")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(width: 30, height: 30)
            }
            .padding(.horizontal, AppTheme.spacingMD)
            .padding(.vertical, AppTheme.spacingSM)
            .background(AppTheme.surfaceMuted)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, AppTheme.spacingXS)
        .popover(isPresented: $showingMemoryCard, arrowEdge: .trailing) {
            memoryCard
                .frame(width: 560, height: 520)
                .background(AppTheme.primary)
        }
    }

    private var memoryCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Memory")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("AI-owned context. The app writes generated notes here and compacts it before it gets too large.")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                Text("\(memorySnapshot.count) / \(NoteMemoryStore.limit())")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(memorySnapshot.count > NoteMemoryStore.compactionThreshold ? AppTheme.accentBlue : AppTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.surface)
                    .clipShape(Capsule())
            }

            ScrollView {
                Text(memorySnapshot.isEmpty ? "No AI notes have been written to memory yet." : memorySnapshot)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(memorySnapshot.isEmpty ? AppTheme.textSecondary : AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(AppTheme.spacingMD)
            }
            .background(AppTheme.surfaceMuted)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))

            HStack {
                Text("Limit")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)

                TextField("", text: $memoryLimitText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .textFieldStyle(.plain)
                    .frame(width: 72)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(AppTheme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onSubmit {
                        saveMemoryLimit()
                    }

                Button {
                    saveMemoryLimit()
                } label: {
                    Text("Set")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                        .frame(height: 32)
                        .padding(.horizontal, AppTheme.spacingMD)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    Task {
                        await compactMemoryNow()
                    }
                } label: {
                    Text("Compact")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                        .frame(height: 32)
                        .padding(.horizontal, AppTheme.spacingMD)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button {
                    clearMemory()
                } label: {
                    Text("Clear")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.primary)
                        .frame(height: 32)
                        .padding(.horizontal, AppTheme.spacingMD)
                        .background(AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppTheme.spacingMD)
        .background(AppTheme.surfaceAlt.opacity(0.42))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
        .padding(AppTheme.spacingSM)
    }

    private func summarizerModelRow(_ model: SummarizerModel) -> some View {
        let isSelected = selectedSummarizerModelIdentity == model.identity

        return Button {
            selectSummarizerModel(model)
        } label: {
            HStack(spacing: AppTheme.spacingMD) {
                if let provider = model.provider {
                    LLMProviderGlyph(provider: provider)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(model.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)

                    Text(model.subtitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.textSecondary)
            }
            .padding(.horizontal, AppTheme.spacingMD)
            .padding(.vertical, AppTheme.spacingSM)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? AppTheme.surfaceAlt.opacity(0.45) : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
                .padding(.leading, 64)
        }
    }

    private var formattingSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            Text("Formatting")
                .font(.title3.weight(.bold))
                .foregroundColor(AppTheme.textPrimary)

            HStack(spacing: AppTheme.spacingMD) {
                VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                    Text("Date Format")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.textSecondary)

                    Picker("", selection: Binding(
                        get: { selectedDateFormat },
                        set: { dateFormatRawValue = $0.rawValue }
                    )) {
                        ForEach(DateDisplayFormat.allCases) { format in
                            Text(format.title).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                    Text("Time Format")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.textSecondary)

                    Picker("", selection: Binding(
                        get: { selectedTimeFormat },
                        set: { timeFormatRawValue = $0.rawValue }
                    )) {
                        ForEach(TimeDisplayFormat.allCases) { format in
                            Text(format.title).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppTheme.spacingLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
    }

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
            HStack {
                Text("Projects")
                    .font(.title3.weight(.bold))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Button {
                    editingTarget = ProjectEditorTarget(project: nil)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            ForEach(viewModel.projects) { project in
                Button {
                    edit(project)
                } label: {
                    HStack(spacing: AppTheme.spacingMD) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(hex: project.colorHex))
                            .frame(width: 32, height: 32)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(project.name)
                                .font(.title3.weight(.semibold))
                                .foregroundColor(AppTheme.textPrimary)
                                .lineLimit(1)

                            if !project.scope.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(project.scope)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .trailing) {
                    Button(role: .destructive) {
                        viewModel.deleteProject(project)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.trailing, AppTheme.spacingMD)
                }
                .padding(.horizontal, AppTheme.spacingMD)
                .padding(.vertical, AppTheme.spacingSM)
                .background(AppTheme.surfaceMuted)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            }
        }
        .padding(AppTheme.spacingLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
    }

    private func edit(_ project: Project) {
        editingTarget = ProjectEditorTarget(project: project)
    }

    private var selectedLLMProvider: LLMProvider {
        LLMProvider(rawValue: selectedLLMProviderRawValue) ?? .openRouter
    }

    private var connectedProviders: [LLMProvider] {
        LLMProvider.allCases.filter { hasSavedCredential(for: $0) }
    }

    private var connectedSummarizerModels: [SummarizerModel] {
        connectedProviders.flatMap { discoveredOrFallbackModels(for: $0) }
    }

    private var selectedSummarizerModelTitle: String {
        guard let selected = connectedSummarizerModels.first(where: { $0.identity == selectedSummarizerModelIdentity }) else {
            return connectedProviders.isEmpty ? "Connect a provider to choose a summarizer." : "Choose a summarizer model."
        }

        return "\(selected.provider?.title ?? "Provider") · \(selected.title)"
    }

    private var systemPromptPreview: String {
        let trimmed = systemPromptText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Default note-writing style." : trimmed
    }

    private var memoryPreview: String {
        let memory = NoteMemoryStore.memoryForPrompt()
        return memory.isEmpty ? "No generated AI memory yet." : "\(memory.count) characters stored."
    }

    private func loadLLMSettings() {
        selectedLLMProviderRawValue = DatabaseManager.shared.appSetting(forKey: LLMProviderPreferenceKeys.selectedProvider)
            ?? LLMProvider.openRouter.rawValue
        selectedSummarizerModelIdentity = savedSummarizerModelIdentity()
        systemPromptText = DatabaseManager.shared.appSetting(forKey: LLMProviderPreferenceKeys.systemPrompt)
            ?? NotePromptDefaults.systemPrompt
        refreshMemorySnapshot()
    }

    private func selectLLMProvider(_ provider: LLMProvider) {
        selectedLLMProviderRawValue = provider.rawValue
        DatabaseManager.shared.setAppSetting(provider.rawValue, forKey: LLMProviderPreferenceKeys.selectedProvider)
        selectedSummarizerModelIdentity = savedSummarizerModelIdentity()
        settingsRefreshID = UUID()
    }

    private func selectSummarizerModel(_ model: SummarizerModel) {
        selectedSummarizerModelIdentity = model.identity
        DatabaseManager.shared.setAppSetting(model.identity, forKey: LLMProviderPreferenceKeys.selectedSummarizerModel)
        settingsRefreshID = UUID()
    }

    private func savedSummarizerModelIdentity() -> String {
        let models = connectedSummarizerModels
        let savedIdentity = DatabaseManager.shared.appSetting(forKey: LLMProviderPreferenceKeys.selectedSummarizerModel)

        if let savedIdentity, models.contains(where: { $0.identity == savedIdentity }) {
            return savedIdentity
        }

        return models.first?.identity ?? ""
    }

    private func discoveredOrFallbackModels(for provider: LLMProvider) -> [SummarizerModel] {
        let discovered = discoveredModels(for: provider)
        return discovered.isEmpty ? SummarizerModel.models(for: provider) : discovered
    }

    private func discoveredModels(for provider: LLMProvider) -> [SummarizerModel] {
        guard
            let json = DatabaseManager.shared.appSetting(forKey: discoveredModelsKey(for: provider)),
            let data = json.data(using: .utf8),
            let models = try? JSONDecoder().decode([SummarizerModel].self, from: data)
        else {
            return []
        }

        return models
    }

    private func saveDiscoveredModels(_ models: [SummarizerModel], for provider: LLMProvider) {
        guard let data = try? JSONEncoder().encode(models),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        DatabaseManager.shared.setAppSetting(json, forKey: discoveredModelsKey(for: provider))
        selectedSummarizerModelIdentity = savedSummarizerModelIdentity()
        settingsRefreshID = UUID()
    }

    private func discoveredModelsKey(for provider: LLMProvider) -> String {
        LLMProviderPreferenceKeys.discoveredModelsPrefix + provider.rawValue
    }

    private func saveSystemPrompt() {
        let trimmed = systemPromptText.trimmingCharacters(in: .whitespacesAndNewlines)
        DatabaseManager.shared.setAppSetting(trimmed.isEmpty ? nil : trimmed, forKey: LLMProviderPreferenceKeys.systemPrompt)
        systemPromptText = trimmed.isEmpty ? NotePromptDefaults.systemPrompt : trimmed
        settingsRefreshID = UUID()
    }

    private func resetSystemPrompt() {
        systemPromptText = NotePromptDefaults.systemPrompt
        DatabaseManager.shared.setAppSetting(nil, forKey: LLMProviderPreferenceKeys.systemPrompt)
        settingsRefreshID = UUID()
    }

    private func insertMemoryToken() {
        if !systemPromptText.contains("@memory") {
            let separator = systemPromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "\n"
            systemPromptText += "\(separator)Nutze @memory als Kontext."
        }
    }

    private func refreshMemorySnapshot() {
        memorySnapshot = NoteMemoryStore.displayMemory()
        memoryLimitText = "\(NoteMemoryStore.limit())"
        settingsRefreshID = UUID()
    }

    private func saveMemoryLimit() {
        let value = Int(memoryLimitText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? NoteMemoryStore.defaultLimit
        NoteMemoryStore.setLimit(value)
        memoryLimitText = "\(NoteMemoryStore.limit())"
        settingsRefreshID = UUID()
    }

    private func clearMemory() {
        NoteMemoryStore.clear()
        refreshMemorySnapshot()
    }

    private func compactMemoryNow() async {
        saveMemoryLimit()
        await NoteMemoryStore.compactIfNeeded(force: true)
        await MainActor.run {
            refreshMemorySnapshot()
        }
    }

    private func refreshModels(for provider: LLMProvider) {
        guard let credential = savedCredential(for: provider), provider.authMode != .connect else {
            saveDiscoveredModels(SummarizerModel.models(for: provider), for: provider)
            return
        }

        isRefreshingModels = true
        modelDiscoveryMessage = "Checking \(provider.title) models..."

        Task {
            let result = await LLMModelDiscovery.fetchModels(for: provider, credential: credential)

            await MainActor.run {
                isRefreshingModels = false
                switch result {
                case .success(let models):
                    saveDiscoveredModels(models, for: provider)
                    modelDiscoveryMessage = "Updated \(models.count) \(provider.title) models."
                case .failure:
                    saveDiscoveredModels(SummarizerModel.models(for: provider), for: provider)
                    modelDiscoveryMessage = "Could not check \(provider.title) live models. Showing default models for now."
                }
            }
        }
    }

    private func refreshConnectedProviderModels(force: Bool = false) {
        let providers = connectedProviders
        guard !providers.isEmpty else { return }

        if !force, providers.allSatisfy({ !discoveredModels(for: $0).isEmpty }) {
            selectedSummarizerModelIdentity = savedSummarizerModelIdentity()
            return
        }

        isRefreshingModels = true
        modelDiscoveryMessage = "Checking connected providers..."

        Task {
            var updatedCount = 0

            for provider in providers {
                guard let credential = savedCredential(for: provider), provider.authMode != .connect else {
                    await MainActor.run {
                        saveDiscoveredModels(SummarizerModel.models(for: provider), for: provider)
                    }
                    updatedCount += 1
                    continue
                }

                let result = await LLMModelDiscovery.fetchModels(for: provider, credential: credential)
                await MainActor.run {
                    switch result {
                    case .success(let models):
                        saveDiscoveredModels(models, for: provider)
                    case .failure:
                        saveDiscoveredModels(SummarizerModel.models(for: provider), for: provider)
                    }
                }
                updatedCount += 1
            }

            await MainActor.run {
                isRefreshingModels = false
                modelDiscoveryMessage = "Checked \(updatedCount) connected provider\(updatedCount == 1 ? "" : "s")."
                selectedSummarizerModelIdentity = savedSummarizerModelIdentity()
            }
        }
    }

    private func providerDescription(for provider: LLMProvider) -> String {
        switch provider {
        case .openRouter:
            return "Route through many hosted models with one API key."
        case .inceptionLabs:
            return "Connect Inception Labs with an API key."
        case .google:
            return "Use Gemini models with a Google API key."
        case .anthropic:
            return "Use Claude models with an Anthropic API key."
        case .openAI:
            return "Use OpenAI models with an API key."
        case .kimi:
            return "Use Kimi coding models with an API key."
        case .xAI:
            return "Use Grok models with an xAI API key."
        case .deepSeek:
            return "Use DeepSeek models with an API key."
        case .lmStudio:
            return "Use a local OpenAI-compatible LM Studio endpoint."
        }
    }

    private func providerActionTitle(for provider: LLMProvider) -> String {
        hasSavedCredential(for: provider) ? "Connected" : "Connect"
    }

    private func providerActionIcon(for provider: LLMProvider) -> String {
        hasSavedCredential(for: provider) ? "checkmark" : "plus"
    }

    private func hasSavedCredential(for provider: LLMProvider) -> Bool {
        savedCredential(for: provider) != nil
    }

    private func savedCredential(for provider: LLMProvider) -> String? {
        if provider.authMode == .connect {
            return isConnected(provider) ? "connected" : nil
        }

        return DatabaseManager.shared.appSetting(forKey: credentialKey(for: provider))
    }

    private func credentialKey(for provider: LLMProvider) -> String {
        LLMProviderPreferenceKeys.credentialPrefix + provider.rawValue
    }

    private func saveCredential(_ value: String, for provider: LLMProvider) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        switch provider.authMode {
        case .apiKey:
            guard !trimmed.isEmpty else { return }
            DatabaseManager.shared.setAppSetting(trimmed, forKey: credentialKey(for: provider))
        case .connect:
            setConnected(true, for: provider)
        case .local:
            guard !trimmed.isEmpty else { return }
            DatabaseManager.shared.setAppSetting(trimmed, forKey: credentialKey(for: provider))
        }

        settingsRefreshID = UUID()
    }

    private func isConnected(_ provider: LLMProvider) -> Bool {
        DatabaseManager.shared.appSetting(forKey: LLMProviderPreferenceKeys.connectedPrefix + provider.rawValue) == "1"
    }

    private func setConnected(_ connected: Bool, for provider: LLMProvider) {
        DatabaseManager.shared.setAppSetting(connected ? "1" : nil, forKey: LLMProviderPreferenceKeys.connectedPrefix + provider.rawValue)
        settingsRefreshID = UUID()
    }

    private var selectedDateFormat: DateDisplayFormat {
        DateDisplayFormat(rawValue: dateFormatRawValue) ?? .dayMonthYear
    }

    private var selectedTimeFormat: TimeDisplayFormat {
        TimeDisplayFormat(rawValue: timeFormatRawValue) ?? .twentyFourHour
    }
}

struct ProjectEditorTarget: Identifiable {
    let id = UUID()
    let project: Project?
}

private struct LLMProviderGlyph: View {
    let provider: LLMProvider

    var body: some View {
        Image(provider.iconAssetName)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .foregroundStyle(AppTheme.textPrimary)
            .padding(7)
        .frame(width: 40, height: 40)
    }
}

private extension LLMProvider {
    var iconAssetName: String {
        switch self {
        case .openRouter:
            return "LLMOpenRouter"
        case .inceptionLabs:
            return "LLMInception"
        case .google:
            return "LLMGoogle"
        case .anthropic:
            return "LLMAnthropic"
        case .openAI:
            return "LLMOpenAI"
        case .kimi:
            return "LLMMoonshot"
        case .xAI:
            return "LLMXAI"
        case .deepSeek:
            return "LLMDeepSeek"
        case .lmStudio:
            return "LLMLmStudio"
        }
    }
}

private enum LLMModelDiscovery {
    struct OpenAIModelList: Decodable {
        let data: [OpenAIModel]
    }

    struct OpenAIModel: Decodable {
        let id: String
    }

    struct GoogleModelList: Decodable {
        let models: [GoogleModel]
    }

    struct GoogleModel: Decodable {
        let name: String
        let displayName: String?
        let supportedGenerationMethods: [String]?
    }

    static func fetchModels(for provider: LLMProvider, credential: String) async -> Result<[SummarizerModel], Error> {
        do {
            let request = try modelRequest(for: provider, credential: credential)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let models = try decodeModels(from: data, provider: provider)
            return .success(models.isEmpty ? SummarizerModel.models(for: provider) : models)
        } catch {
            return .failure(error)
        }
    }

    private static func modelRequest(for provider: LLMProvider, credential: String) throws -> URLRequest {
        guard let url = modelURL(for: provider, credential: credential) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        switch provider {
        case .google:
            break
        case .anthropic:
            request.setValue(credential, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        default:
            request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private static func modelURL(for provider: LLMProvider, credential: String) -> URL? {
        switch provider {
        case .openRouter:
            return URL(string: "https://openrouter.ai/api/v1/models")
        case .inceptionLabs:
            return URL(string: "https://api.inceptionlabs.ai/v1/models")
        case .google:
            var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models")
            components?.queryItems = [URLQueryItem(name: "key", value: credential)]
            return components?.url
        case .anthropic:
            return URL(string: "https://api.anthropic.com/v1/models")
        case .openAI:
            return URL(string: "https://api.openai.com/v1/models")
        case .kimi:
            return URL(string: "https://api.moonshot.ai/v1/models")
        case .xAI:
            return URL(string: "https://api.x.ai/v1/models")
        case .deepSeek:
            return URL(string: "https://api.deepseek.com/v1/models")
        case .lmStudio:
            return localModelsURL(from: credential)
        }
    }

    private static func localModelsURL(from endpoint: String) -> URL? {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed) else { return nil }
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if path.hasSuffix("models") {
            return components.url
        }

        components.path = "/" + ([path, "models"].filter { !$0.isEmpty }.joined(separator: "/"))
        return components.url
    }

    private static func decodeModels(from data: Data, provider: LLMProvider) throws -> [SummarizerModel] {
        if provider == .google {
            let decoded = try JSONDecoder().decode(GoogleModelList.self, from: data)
            return decoded.models
                .filter { model in
                    let methods = model.supportedGenerationMethods ?? []
                    return methods.isEmpty || methods.contains("generateContent")
                }
                .map { model in
                    let id = model.name.replacingOccurrences(of: "models/", with: "")
                    return SummarizerModel(
                        provider: provider,
                        id: id,
                        title: model.displayName ?? id,
                        subtitle: model.name
                    )
                }
        }

        let decoded = try JSONDecoder().decode(OpenAIModelList.self, from: data)
        return decoded.data.map { model in
            SummarizerModel(
                provider: provider,
                id: model.id,
                title: displayTitle(from: model.id),
                subtitle: model.id
            )
        }
    }

    private static func displayTitle(from modelID: String) -> String {
        modelID
            .split(separator: "/")
            .last
            .map(String.init)?
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized ?? modelID
    }
}

private struct RouteGlyph: View {
    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 8, y: 14))
                path.addLine(to: CGPoint(x: 23, y: 14))
                path.addLine(to: CGPoint(x: 30, y: 9))
                path.move(to: CGPoint(x: 23, y: 14))
                path.addLine(to: CGPoint(x: 30, y: 19))
                path.move(to: CGPoint(x: 32, y: 26))
                path.addLine(to: CGPoint(x: 17, y: 26))
                path.addLine(to: CGPoint(x: 10, y: 21))
                path.move(to: CGPoint(x: 17, y: 26))
                path.addLine(to: CGPoint(x: 10, y: 31))
            }
            .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
    }
}

private struct InceptionGlyph: View {
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .stroke(lineWidth: 2)
                    .frame(width: CGFloat(24 - index * 6), height: CGFloat(24 - index * 6))
                    .rotationEffect(.degrees(45))
            }
        }
    }
}

private struct GoogleGlyph: View {
    var body: some View {
        Text("G")
            .font(.system(size: 25, weight: .black, design: .rounded))
            .frame(width: 34, height: 34)
    }
}

private struct AnthropicGlyph: View {
    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 9, y: 30))
                path.addLine(to: CGPoint(x: 18, y: 10))
                path.addLine(to: CGPoint(x: 22, y: 10))
                path.addLine(to: CGPoint(x: 31, y: 30))
                path.move(to: CGPoint(x: 14, y: 23))
                path.addLine(to: CGPoint(x: 26, y: 23))
            }
            .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        }
    }
}

private struct OpenAIGlyph: View {
    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                Capsule()
                    .stroke(lineWidth: 2.3)
                    .frame(width: 15, height: 8)
                    .offset(x: 7)
                    .rotationEffect(.degrees(Double(index) * 60))
            }
            Circle()
                .stroke(lineWidth: 1.7)
                .frame(width: 11, height: 11)
        }
    }
}

private struct KimiGlyph: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.textPrimary)
                .frame(width: 25, height: 25)
            Circle()
                .fill(AppTheme.surfaceMuted)
                .frame(width: 22, height: 22)
                .offset(x: 7, y: -3)
            Circle()
                .fill(AppTheme.textPrimary)
                .frame(width: 5, height: 5)
                .offset(x: 9, y: 10)
        }
    }
}

private struct XAIGlyph: View {
    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 10, y: 10))
                path.addLine(to: CGPoint(x: 30, y: 30))
                path.move(to: CGPoint(x: 29, y: 10))
                path.addLine(to: CGPoint(x: 13, y: 30))
            }
            .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
        }
    }
}

private struct DeepSeekGlyph: View {
    var body: some View {
        ZStack {
            Capsule()
                .stroke(lineWidth: 3)
                .frame(width: 27, height: 18)
                .offset(x: -1, y: 2)
            Circle()
                .fill(AppTheme.textPrimary)
                .frame(width: 4, height: 4)
                .offset(x: 7, y: -1)
            Path { path in
                path.move(to: CGPoint(x: 8, y: 23))
                path.addQuadCurve(to: CGPoint(x: 5, y: 30), control: CGPoint(x: 5, y: 25))
                path.move(to: CGPoint(x: 30, y: 20))
                path.addLine(to: CGPoint(x: 34, y: 14))
                path.addLine(to: CGPoint(x: 34, y: 26))
                path.closeSubpath()
            }
            .fill(AppTheme.textPrimary)
        }
    }
}

private struct LMStudioGlyph: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .stroke(lineWidth: 2.4)
                .frame(width: 27, height: 18)
            Rectangle()
                .fill(AppTheme.textPrimary)
                .frame(width: 13, height: 2.4)
                .offset(y: 13)
            Rectangle()
                .fill(AppTheme.textPrimary)
                .frame(width: 2.4, height: 7)
                .offset(y: 9)
        }
    }
}

private struct LLMProviderConfigSheet: View {
    let provider: LLMProvider
    let isSelected: Bool
    let savedCredential: String?
    let onSelect: () -> Void
    let onSaveCredential: (String) -> Void
    let onConnect: () -> Void
    let onCancel: () -> Void

    @State private var credential = ""

    var body: some View {
        ZStack {
            AppTheme.primary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: AppTheme.spacingLG) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(provider.title)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)

                        Text(subtitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    Spacer()

                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.surface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                content

                Spacer()

                HStack(spacing: AppTheme.spacingSM) {
                    Button(action: onSelect) {
                        Text(isSelected ? "Selected" : "Use Provider")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
                    }
                    .buttonStyle(.plain)

                    primaryAction
                }
            }
            .padding(AppTheme.spacingLG)
        }
        .onAppear {
            if provider.authMode == .local, let savedCredential {
                credential = savedCredential
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch provider.authMode {
        case .apiKey:
            SecureField(savedCredential == nil ? "Enter API key" : "Replace saved API key", text: $credential)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .padding(AppTheme.spacingMD)
                .background(AppTheme.surfaceMuted)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))

        case .connect:
            Text("This provider uses an account connection flow. TimeTracker will remember the connection state in the local database once connected.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .padding(AppTheme.spacingMD)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))

        case .local:
            TextField("http://localhost:1234/v1", text: $credential)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .padding(AppTheme.spacingMD)
                .background(AppTheme.surfaceMuted)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        }
    }

    @ViewBuilder
    private var primaryAction: some View {
        switch provider.authMode {
        case .apiKey, .local:
            Button(action: { onSaveCredential(credential) }) {
                Text(provider.authMode == .local ? "Save Endpoint" : "Save Key")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            }
            .buttonStyle(.plain)
            .disabled(credential.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        case .connect:
            Button(action: onConnect) {
                Text(savedCredential == nil ? "Connect" : "Reconnect")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            }
            .buttonStyle(.plain)
        }
    }

    private var subtitle: String {
        switch provider.authMode {
        case .apiKey:
            return savedCredential == nil
                ? "Enter an API key to use this provider."
                : "An API key is saved in the local database."
        case .connect:
            return savedCredential == nil
                ? "Connect this provider to use it."
                : "Connection is saved in the local database."
        case .local:
            return savedCredential == nil
                ? "Configure the local OpenAI-compatible endpoint."
                : "Local endpoint is saved in the database."
        }
    }
}
