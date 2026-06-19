import Foundation
import SwiftUI

@MainActor
@Observable
final class TrainingSessionService {
    private let projectRepository: ProjectRepository

    var activeProjectUID: String?
    var activeProjectName: String?
    var requestUID: String?
    var clipCount = 0
    var backendStatus: String?
    var history: [TrainingStatusReport] = []
    var error: String?
    var isStarting = false
    var isSheetPresented = false
    var startedAt: Date?
    var elapsedDuration: TimeInterval = 0

    private var pollingTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?

    init(loginService: AuthenticationService) {
        self.projectRepository = ProjectRepository(loginService: loginService)
    }

    var hasActiveSession: Bool {
        requestUID != nil
    }

    var isCompleted: Bool {
        guard let backendStatus else { return false }
        let normalized = backendStatus.lowercased()
        return normalized.contains("complete") || normalized.contains("success")
    }

    var didFail: Bool {
        guard let backendStatus else { return false }
        let normalized = backendStatus.lowercased()
        return normalized.contains("fail") || normalized.contains("error")
    }

    var isRunning: Bool {
        hasActiveSession && !isCompleted && !didFail
    }

    var trainBadgeKind: RSRBadgeKind {
        if isCompleted { return .ready }
        if isRunning { return .running }
        return .none
    }

    var modelsBadgeKind: RSRBadgeKind {
        isCompleted ? .ready : .none
    }

    var displayState: RSRTrainingState? {
        guard hasActiveSession else { return nil }
        if isCompleted {
            return .complete
        }

        let elapsed = max(elapsedDuration, 0)
        return .inProgress(
            phase: phase(for: elapsed),
            fraction: progressFraction(for: elapsed),
            etaText: etaText(for: elapsed)
        )
    }

    func startTraining(
        projectUID: String,
        projectName: String,
        clipCount: Int
    ) async {
        isStarting = true
        error = nil

        do {
            let request = try await projectRepository.startTraining(projectUID: projectUID)
            activeProjectUID = projectUID
            activeProjectName = projectName
            requestUID = request.requestUID
            self.clipCount = clipCount
            backendStatus = "starting"
            history = []
            startedAt = Date()
            elapsedDuration = 0
            isSheetPresented = true
            beginProgressClock()
            await refreshStatus()
            beginPolling()
        } catch {
            self.error = error.localizedDescription
        }

        isStarting = false
    }

    func refreshStatus() async {
        guard let requestUID else { return }

        do {
            let snapshot = try await projectRepository.trainingStatus(trainingRequestUID: requestUID)
            backendStatus = snapshot.status
            history = (try? await projectRepository.trainingStatusHistory(trainingRequestUID: requestUID)) ?? history

            if isCompleted || didFail {
                stopBackgroundTasks()
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func leaveRunning() {
        isSheetPresented = false
    }

    func reopenSheet() {
        guard hasActiveSession else { return }
        isSheetPresented = true
    }

    func doneViewingCompletion() {
        isSheetPresented = false
    }

    func cancelTraining() {
        error = "Cancel training is not supported by the API yet."
    }

    func markInstalled(projectUID: String) {
        guard isCompleted, activeProjectUID == projectUID else { return }
        reset()
    }

    func clearError() {
        error = nil
    }

    func reset() {
        stopBackgroundTasks()
        activeProjectUID = nil
        activeProjectName = nil
        requestUID = nil
        clipCount = 0
        backendStatus = nil
        history = []
        error = nil
        isStarting = false
        isSheetPresented = false
        startedAt = nil
        elapsedDuration = 0
    }

    private func beginPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if Task.isCancelled { return }

                await self.refreshStatus()

                if self.isCompleted || self.didFail {
                    return
                }
            }
        }
    }

    private func beginProgressClock() {
        progressTask?.cancel()
        progressTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                if let startedAt = self.startedAt {
                    self.elapsedDuration = Date().timeIntervalSince(startedAt)
                }

                if self.isCompleted || self.didFail {
                    return
                }

                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func stopBackgroundTasks() {
        pollingTask?.cancel()
        progressTask?.cancel()
        pollingTask = nil
        progressTask = nil
    }

    private func phase(for elapsed: TimeInterval) -> RSRTrainingPhase {
        switch elapsed {
        case ..<12:
            return .uploading
        case ..<25:
            return .preprocessing
        case ..<180:
            return .training
        default:
            return .packaging
        }
    }

    private func progressFraction(for elapsed: TimeInterval) -> Double {
        switch elapsed {
        case ..<12:
            return lerp(from: 0.04, to: 0.12, progress: elapsed / 12)
        case ..<25:
            return lerp(from: 0.12, to: 0.18, progress: (elapsed - 12) / 13)
        case ..<180:
            return lerp(from: 0.18, to: 0.94, progress: (elapsed - 25) / 155)
        default:
            return 0.97
        }
    }

    private func etaText(for elapsed: TimeInterval) -> String {
        let remainingSeconds = max(0, Int(180 - elapsed.rounded()))
        if remainingSeconds <= 0 {
            return "Finishing up"
        }
        if remainingSeconds < 60 {
            return "Less than a minute remaining"
        }

        let minutes = Int(ceil(Double(remainingSeconds) / 60.0))
        return "~\(minutes) min remaining"
    }

    private func lerp(from start: Double, to end: Double, progress: Double) -> Double {
        start + (end - start) * min(max(progress, 0), 1)
    }
}
