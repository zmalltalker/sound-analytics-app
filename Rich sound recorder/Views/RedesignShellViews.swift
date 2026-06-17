import SwiftUI

struct ContextHeader: View {
    let title: String
    let subtitle: String?
    let onSwitch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProjectContextToast(title: title, onSwitch: onSwitch)

            if let subtitle {
                Text(subtitle)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.leading, 6)
            }
        }
    }
}

struct ProjectContextToast: View {
    let title: String
    let onSwitch: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.88, green: 0.94, blue: 1.0))

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Spacer(minLength: 8)

            Button("Switch", action: onSwitch)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.95))
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    Capsule()
                        .fill(.regularMaterial.opacity(0.75))
                )
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 18, y: 8)
    }
}

struct InstrumentCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.06))
            )
    }
}

struct TintedActionButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(tint)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.09 : 0.06))
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

struct ProjectSwitcherSheet: View {
    @Environment(RedesignAppContext.self) private var appContext
    @Environment(\.dismiss) private var dismiss

    let onCreateProject: () -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(appContext.projects) { project in
                    Button {
                        Task {
                            await appContext.setActiveProject(project.uid)
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: appContext.activeProjectUID == project.uid ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(appContext.activeProjectUID == project.uid ? Color(red: 0.41, green: 0.80, blue: 1.0) : .secondary)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(project.name)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)

                                Text(projectMetadata(for: project))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(appContext.activeProjectUID == project.uid ? Color(red: 0.41, green: 0.80, blue: 1.0).opacity(0.12) : Color.white.opacity(0.06))
                    )
                }

                Button {
                    dismiss()
                    onCreateProject()
                } label: {
                    Label("+ New project", systemImage: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.white.opacity(0.06))
            }
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Switch Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .presentationDetents([.medium, .large])
        }
        .preferredColorScheme(.dark)
    }

    private func projectMetadata(for project: Project) -> String {
        let labelsCount = project.labelUIDs.count
        let installedVersions = appContext.installedModels
            .filter { $0.projectUID == project.uid }
            .map(\.version)
            .sorted { compareModelVersion($0, $1) == .orderedDescending }

        if let installedVersion = installedVersions.first {
            return "\(labelsCount) labels · v\(installedVersion) on device"
        }

        if let cloudVersion = appContext.latestKnownVersion(for: project.uid) {
            return "\(labelsCount) labels · v\(cloudVersion) cloud"
        }

        return labelsCount == 0 ? "0 labels · not ready" : "\(labelsCount) labels · not ready"
    }
}
