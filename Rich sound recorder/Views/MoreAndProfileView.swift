import SwiftUI

struct MoreTab: View {
    let loginService: AuthenticationService
    @Binding var showProfileSheet: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                List {
                    Section("Browse") {
                        NavigationLink {
                            ProjectsTab(
                                loginService: loginService,
                                showProfileSheet: $showProfileSheet,
                                wrapInNavigation: false
                            )
                        } label: {
                            moreRow(
                                title: "Projects",
                                subtitle: "Manage project groups and assigned labels",
                                systemImage: "folder.fill"
                            )
                        }

                        NavigationLink {
                            LabelsTab(
                                loginService: loginService,
                                showProfileSheet: $showProfileSheet,
                                wrapInNavigation: false
                            )
                        } label: {
                            moreRow(
                                title: "Labels",
                                subtitle: "Create and review training labels",
                                systemImage: "tag.fill"
                            )
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.06))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showProfileSheet = true
                    } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.cyan)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func moreRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.cyan)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

struct UploadLabelSheet: View {
    let fileURL: URL?
    let labels: [RecorderLabel]
    let isLoadingLabels: Bool
    let labelLoadingError: String?
    @Binding var selectedLabelUID: String?
    let isUploading: Bool
    let onCancel: () -> Void
    let onRetry: () -> Void
    let onUpload: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                Group {
                    if isLoadingLabels {
                        ProgressView("Loading labels...")
                            .tint(.cyan)
                    } else {
                        Form {
                            Section("Recording") {
                                Text(fileURL?.lastPathComponent ?? "Unknown file")
                                    .foregroundStyle(.primary)
                            }
                            .listRowBackground(Color.white.opacity(0.06))

                            if let labelLoadingError {
                                Section {
                                    Text(labelLoadingError)
                                        .font(.caption)
                                        .foregroundStyle(.red)

                                    Button("Retry", action: onRetry)
                                        .foregroundStyle(.cyan)
                                }
                                .listRowBackground(Color.red.opacity(0.12))
                            } else if labels.isEmpty {
                                Section {
                                    Text("No labels available")
                                        .foregroundStyle(.secondary)
                                }
                                .listRowBackground(Color.white.opacity(0.06))
                            } else {
                                Section("Select Label") {
                                    ForEach(labels) { label in
                                        Button {
                                            selectedLabelUID = label.uid
                                        } label: {
                                            HStack(spacing: 12) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(label.name)
                                                        .foregroundStyle(.primary)

                                                    if !label.description.isEmpty {
                                                        Text(label.description)
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                    }
                                                }

                                                Spacer()

                                                if selectedLabelUID == label.uid {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundStyle(.cyan)
                                                }
                                            }
                                        }
                                    }
                                }
                                .listRowBackground(Color.white.opacity(0.06))
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Upload Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .foregroundStyle(.cyan)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isUploading {
                        ProgressView()
                            .tint(.cyan)
                    } else {
                        Button("Upload", action: onUpload)
                            .foregroundStyle(.cyan)
                            .disabled(isLoadingLabels || labels.isEmpty || selectedLabelUID == nil || labelLoadingError != nil)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }
}

struct ProfileSheet: View {
    let loginService: AuthenticationService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        VStack(spacing: 12) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 72))
                                .foregroundStyle(.cyan)

                            if let username = loginService.username {
                                Text(username)
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }

                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Signed in")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 20)

                        if let tokenInfo = loginService.getTokenInfo() {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Keychain Data")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(0.5)

                                VStack(spacing: 12) {
                                    InfoRow(label: "Username", value: tokenInfo.username ?? "Unknown")
                                    InfoRow(label: "Account ID", value: tokenInfo.homeAccountId)
                                    InfoRow(label: "Environment", value: tokenInfo.environment ?? "Unknown")
                                    InfoRow(label: "Keychain Group", value: "ai.resonyx.ios-recorder")
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.06))
                                )

                                Text("Access tokens, refresh tokens, and ID tokens are securely stored in iOS Keychain")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 20)
                        }

                        Button {
                            loginService.logout()
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.title3)
                                Text("Sign Out")
                                    .font(.headline)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.red.opacity(0.8))
                            )
                            .padding(.horizontal, 40)
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.cyan)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.cyan)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
