import Foundation
import SwiftUI

enum AppSection: Hashable {
    case train
    case detect
    case models
    case settings
}

struct InstalledProjectModel: Identifiable, Hashable {
    let projectUID: String
    let version: String
    let displayName: String
    let labelNames: [String]
    let sizeBytes: Int64
    let archiveURL: URL
    let modifiedAt: Date?

    var id: String { "\(projectUID)::\(version)" }
    var labelCount: Int { labelNames.count }
}

@MainActor
@Observable
final class RedesignAppContext {
    private let projectRepository: ProjectRepository
    private let labelRepository: LabelRepository
    private let trainingSession: TrainingSessionService

    private let activeProjectKey = "redesign.activeProjectUID"
    private let defaultModelKey = "redesign.defaultModelVersions"

    var projects: [Project] = []
    var labels: [RecorderLabel] = []
    var activeProjectUID: String?
    var defaultModelVersionsByProject: [String: String] = [:]
    var availableModelVersionsByProject: [String: [String]] = [:]
    var modelSpecsByProjectVersion: [String: ProjectModelSpecs] = [:]
    var isLoadingProjects = false
    var isLoadingLabels = false
    var projectError: String?
    var labelError: String?

    init(loginService: AuthenticationService, trainingSession: TrainingSessionService) {
        self.projectRepository = ProjectRepository(loginService: loginService)
        self.labelRepository = LabelRepository(loginService: loginService)
        self.trainingSession = trainingSession
        self.activeProjectUID = UserDefaults.standard.string(forKey: activeProjectKey)
        if let data = UserDefaults.standard.data(forKey: defaultModelKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            self.defaultModelVersionsByProject = decoded
        }
    }

    var activeProject: Project? {
        guard let activeProjectUID else { return nil }
        return projects.first(where: { $0.uid == activeProjectUID })
    }

    var installedModels: [InstalledProjectModel] {
        InstalledModelScanner().scanInstalledModels()
    }

    var activeProjectInstalledModels: [InstalledProjectModel] {
        guard let activeProject else { return [] }
        return installedModels
            .filter { $0.projectUID == activeProject.uid }
            .sorted(by: { compareModelVersion($0.version, $1.version) == .orderedDescending })
    }

    var totalInstalledModelCount: Int {
        installedModels.count
    }

    var totalInstalledStorageBytes: Int64 {
        installedModels.reduce(0) { $0 + $1.sizeBytes }
    }

    func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.refreshProjects() }
            group.addTask { await self.refreshLabels() }
        }

        if let activeProject {
            await refreshAvailableModelVersions(for: activeProject.uid, force: true)
        }

        for project in projects {
            await refreshAvailableModelVersions(for: project.uid, force: true)
        }

    }

    func refreshProjects() async {
        isLoadingProjects = true
        projectError = nil

        do {
            let loadedProjects = try await projectRepository.list()
            projects = loadedProjects

            if let activeProjectUID, loadedProjects.contains(where: { $0.uid == activeProjectUID }) {
                self.activeProjectUID = activeProjectUID
            } else {
                self.activeProjectUID = loadedProjects.first?.uid
                persistActiveProject()
            }
        } catch {
            projectError = error.localizedDescription
        }

        isLoadingProjects = false
    }

    func refreshLabels() async {
        isLoadingLabels = true
        labelError = nil

        do {
            labels = try await labelRepository.list()
        } catch {
            labelError = error.localizedDescription
        }

        isLoadingLabels = false
    }

    func setActiveProject(_ projectUID: String) async {
        activeProjectUID = projectUID
        persistActiveProject()
        await refreshAvailableModelVersions(for: projectUID, force: true)

        if let defaultVersion = defaultModelVersionsByProject[projectUID],
           !activeProjectInstalledModels.contains(where: { $0.version == defaultVersion }) {
            defaultModelVersionsByProject.removeValue(forKey: projectUID)
            persistDefaultModels()
        }
    }

    func refreshAvailableModelVersions(for projectUID: String, force: Bool = false) async {
        if !force, availableModelVersionsByProject[projectUID] != nil {
            return
        }

        do {
            let versions = try await projectRepository.availableModelVersions(projectUID: projectUID)
            availableModelVersionsByProject[projectUID] = versions
        } catch {
            availableModelVersionsByProject[projectUID] = []
        }
    }

    func modelSpecs(projectUID: String, version: String) async throws -> ProjectModelSpecs {
        let key = modelSpecKey(projectUID: projectUID, version: version)
        if let cached = modelSpecsByProjectVersion[key] {
            return cached
        }

        let specs = try await projectRepository.modelSpecs(projectUID: projectUID, modelVersion: version)
        modelSpecsByProjectVersion[key] = specs
        return specs
    }

    func installModel(projectUID: String, version: String) async throws {
        let specs = try await modelSpecs(projectUID: projectUID, version: version)
        let projectName = projects.first(where: { $0.uid == projectUID })?.name ?? "Project"
        let labelNames = resolvedModelLabelNames(for: specs)
        let samplingRate = 16_000
        let inputNSamples = max(specs.trained_sample_size ?? samplingRate, 1)

        _ = try await projectRepository.downloadIOSModel(
            projectUID: projectUID,
            modelVersion: version,
            samplingRate: samplingRate,
            inputNSamples: inputNSamples,
            displayName: projectName,
            labelNames: labelNames
        )

        if defaultModelVersionsByProject[projectUID] == nil {
            setDefaultModelVersion(version, for: projectUID)
        }

        trainingSession.markInstalled(projectUID: projectUID)
    }

    func removeInstalledModel(projectUID: String, version: String) throws {
        guard let installedModel = installedModels.first(where: { $0.projectUID == projectUID && $0.version == version }) else {
            return
        }

        try? FileManager.default.removeItem(at: installedModel.archiveURL)
        try? FileManager.default.removeItem(at: installedModel.archiveURL.appendingPathExtension("metadata.json"))

        if defaultModelVersionsByProject[projectUID] == version {
            defaultModelVersionsByProject.removeValue(forKey: projectUID)
            persistDefaultModels()
        }
    }

    func setDefaultModelVersion(_ version: String, for projectUID: String) {
        defaultModelVersionsByProject[projectUID] = version
        persistDefaultModels()
    }

    func defaultInstalledModel(for projectUID: String) -> InstalledProjectModel? {
        let models = installedModels.filter { $0.projectUID == projectUID }

        if let version = defaultModelVersionsByProject[projectUID],
           let match = models.first(where: { $0.version == version }) {
            return match
        }

        if models.count == 1 {
            return models[0]
        }

        return nil
    }

    func selectedOrOnlyInstalledModel(for projectUID: String, selectedVersion: String?) -> InstalledProjectModel? {
        let models = installedModels.filter { $0.projectUID == projectUID }

        if let selectedVersion,
           let selectedModel = models.first(where: { $0.version == selectedVersion }) {
            return selectedModel
        }

        return defaultInstalledModel(for: projectUID)
    }

    func projectLabels(for project: Project) -> [RecorderLabel] {
        let labelsByUID = Dictionary(uniqueKeysWithValues: labels.map { ($0.uid, $0) })
        return project.labelUIDs.map { labelUID in
            labelsByUID[labelUID] ?? RecorderLabel(
                uid: labelUID,
                guid: labelUID,
                name: labelUID,
                user_id: "",
                duration: 0,
                description: ""
            )
        }
    }

    func latestKnownVersion(for projectUID: String) -> String? {
        let versions = availableModelVersionsByProject[projectUID] ?? []
        return versions.sorted(by: { compareModelVersion($0, $1) == .orderedDescending }).first
    }

    func resolvedModelLabelNames(for specs: ProjectModelSpecs) -> [String] {
        let labelsByUID = Dictionary(uniqueKeysWithValues: labels.map { ($0.uid, $0.name) })

        let orderedEntries = specs.label_dict.sorted { lhs, rhs in
            switch (Int(lhs.key), Int(rhs.key)) {
            case let (left?, right?):
                return left < right
            default:
                return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
            }
        }

        return orderedEntries.map { key, value in
            if let labelName = labelsByUID[key] {
                return labelName
            }

            if let labelName = labelsByUID[value] {
                return labelName
            }

            return key
        }
    }

    private func persistActiveProject() {
        UserDefaults.standard.set(activeProjectUID, forKey: activeProjectKey)
    }

    private func persistDefaultModels() {
        if let data = try? JSONEncoder().encode(defaultModelVersionsByProject) {
            UserDefaults.standard.set(data, forKey: defaultModelKey)
        }
    }

    private func modelSpecKey(projectUID: String, version: String) -> String {
        "\(projectUID)::\(version)"
    }
}

private struct InstalledModelScanner {
    private struct DownloadedModelMetadata: Codable {
        let displayName: String
        let labelNames: [String]
        let modelVersion: String
        let projectUID: String
    }

    func scanInstalledModels() -> [InstalledProjectModel] {
        guard let docsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let fileURLs = try? FileManager.default.contentsOfDirectory(
                at: docsDirectory,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }

        return fileURLs
            .filter { $0.pathExtension.lowercased() == "zip" && $0.lastPathComponent.hasPrefix("model_") }
            .compactMap { archiveURL in
                let metadataURL = archiveURL.appendingPathExtension("metadata.json")
                let metadata = loadMetadata(from: metadataURL) ?? fallbackMetadata(for: archiveURL)
                guard let metadata else { return nil }

                let values = try? archiveURL.resourceValues(forKeys: [.fileSizeKey])
                let sizeBytes = Int64(values?.fileSize ?? 0)

                return InstalledProjectModel(
                    projectUID: metadata.projectUID,
                    version: metadata.modelVersion,
                    displayName: metadata.displayName,
                    labelNames: metadata.labelNames,
                    sizeBytes: sizeBytes,
                    archiveURL: archiveURL,
                    modifiedAt: values?.contentModificationDate
                )
            }
    }

    private func loadMetadata(from metadataURL: URL) -> DownloadedModelMetadata? {
        guard let data = try? Data(contentsOf: metadataURL) else { return nil }
        return try? JSONDecoder().decode(DownloadedModelMetadata.self, from: data)
    }

    private func fallbackMetadata(for archiveURL: URL) -> DownloadedModelMetadata? {
        let stem = archiveURL.deletingPathExtension().lastPathComponent
        let prefix = "model_"

        guard stem.hasPrefix(prefix) else { return nil }

        let rawValue = String(stem.dropFirst(prefix.count))
        guard let separatorIndex = rawValue.lastIndex(of: "_") else { return nil }

        let projectIdentifier = String(rawValue[..<separatorIndex])
        let modelVersion = String(rawValue[rawValue.index(after: separatorIndex)...])

        return DownloadedModelMetadata(
            displayName: "Project \(projectIdentifier.prefix(8))",
            labelNames: [],
            modelVersion: modelVersion,
            projectUID: projectIdentifier
        )
    }
}

func compareModelVersion(_ lhs: String, _ rhs: String) -> ComparisonResult {
    switch (Int(lhs), Int(rhs)) {
    case let (left?, right?):
        if left == right { return .orderedSame }
        return left < right ? .orderedAscending : .orderedDescending
    default:
        return lhs.localizedStandardCompare(rhs)
    }
}

func formattedStorage(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}
