import SwiftUI
import UIKit

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

struct SuccessToast: View {
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color(red: 0.41, green: 0.80, blue: 1.0))
                .symbolEffect(.bounce, options: .nonRepeating)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(.regularMaterial.opacity(0.92))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 18, y: 8)
    }
}

enum AppHaptics {
    @MainActor private static let stepGenerator = UISelectionFeedbackGenerator()
    @MainActor private static let successGenerator = UINotificationFeedbackGenerator()
    @MainActor private static let errorGenerator = UINotificationFeedbackGenerator()

    @MainActor
    static func stepTick() {
        stepGenerator.prepare()
        stepGenerator.selectionChanged()
    }

    @MainActor
    static func success() {
        successGenerator.prepare()
        successGenerator.notificationOccurred(.success)
    }

    @MainActor
    static func failure() {
        errorGenerator.prepare()
        errorGenerator.notificationOccurred(.error)
    }
}

struct ProjectSwitcherSheet: View {
    @Environment(RedesignAppContext.self) private var appContext
    @Environment(\.dismiss) private var dismiss

    let onCreateProject: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RSRSpace.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Select project")
                            .font(.rsrTitle)
                            .tracking(RSRTracking.title)
                            .foregroundStyle(RSR.labelPrimary)

                        Text("Training, detection, and models all follow the active project.")
                            .font(.rsrSubhead)
                            .foregroundStyle(RSR.labelSecondary)
                    }

                    if appContext.projects.isEmpty {
                        RSRCard {
                            VStack(alignment: .leading, spacing: RSRSpace.sm) {
                                Text("No projects yet")
                                    .font(.rsrBody.weight(.semibold))
                                    .foregroundStyle(RSR.labelPrimary)

                                Text("Create a project to start collecting audio and training models.")
                                    .font(.rsrSubhead)
                                    .foregroundStyle(RSR.labelSecondary)
                            }
                        }
                    } else {
                        VStack(spacing: RSRSpace.sm) {
                            ForEach(appContext.projects) { project in
                                ProjectSwitcherRow(
                                    project: project,
                                    metadata: projectMetadata(for: project),
                                    isSelected: appContext.activeProjectUID == project.uid
                                ) {
                                    Task {
                                        await appContext.setActiveProject(project.uid)
                                        await MainActor.run {
                                            AppHaptics.success()
                                        }
                                        dismiss()
                                    }
                                }
                            }
                        }
                    }

                    RSRSecondaryButton(title: "New project") {
                        dismiss()
                        onCreateProject()
                    }
                }
            }
            .padding(.horizontal, RSRSpace.screen)
            .padding(.top, RSRSpace.md)
            .padding(.bottom, RSRSpace.lg)
            .background(RSR.canvas.ignoresSafeArea())
            .navigationTitle("Switch Project")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.medium, .large])
        }
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

private struct ProjectSwitcherRow: View {
    let project: Project
    let metadata: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RSRGlyphTile(size: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(project.name)
                        .font(.rsrBody.weight(.semibold))
                        .foregroundStyle(RSR.labelPrimary)
                        .lineLimit(1)

                    Text(metadata)
                        .font(.rsrSubhead)
                        .foregroundStyle(RSR.labelSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? RSR.accent : RSR.labelTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .rsrGlass(
                .regular,
                radius: RSRRadius.control,
                fill: isSelected ? RSR.accentTint : RSR.surfaceGlass,
                elevation: .card
            )
        }
        .buttonStyle(.plain)
    }
}

struct DetectModelSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let models: [InstalledProjectModel]
    let selectedVersion: String?
    let onSelect: (InstalledProjectModel) -> Void

    var body: some View {
        NavigationStack {
            List {
                if models.isEmpty {
                    Text("No on-device models available for this project.")
                        .font(.rsrSubhead)
                        .foregroundStyle(RSR.labelSecondary)
                        .listRowBackground(RSR.surfaceGlass)
                } else {
                    ForEach(models) { model in
                        Button {
                            onSelect(model)
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: selectedVersion == model.version ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(selectedVersion == model.version ? RSR.accent : RSR.labelSecondary)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Model v\(model.version)")
                                        .font(.rsrBody.weight(.semibold))
                                        .foregroundStyle(RSR.labelPrimary)

                                    Text(modelMetadata(for: model))
                                        .font(.rsrMeta)
                                        .foregroundStyle(RSR.labelSecondary)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(selectedVersion == model.version ? RSR.accentTint : RSR.surfaceGlass)
                        )
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(RSR.canvas.ignoresSafeArea())
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.medium, .large])
        }
    }

    private func modelMetadata(for model: InstalledProjectModel) -> String {
        let modifiedText = model.modifiedAt?.formatted(date: .abbreviated, time: .omitted) ?? "On device"
        return "\(modifiedText) · \(model.labelCount) labels · \(formattedStorage(model.sizeBytes))"
    }
}
