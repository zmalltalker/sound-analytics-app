//
//  ContentView.swift
//  Rich sound recorder
//
//  Created by Marius Mathiesen on 04/03/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var lastRecordingURL: URL?
    @State private var loginService = LoginService()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 32) {
                    VStack(spacing: 12) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(.cyan)

                        Text("Rich Sound Recorder")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text("High-quality audio recording with real-time frequency analysis")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }

                    VStack(spacing: 12) {
                        NavigationLink {
                            RecordingView { url in
                                lastRecordingURL = url
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "mic.fill")
                                    .font(.title3)
                                Text("Start Recording")
                                    .font(.headline)
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.cyan)
                            )
                            .padding(.horizontal, 40)
                        }

                        if loginService.isLoggedIn {
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("Logged in as")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(loginService.username ?? "unknown")
                                        .font(.caption)
                                        .foregroundStyle(.cyan)
                                }

                                Button {
                                    loginService.logout()
                                } label: {
                                    Text("Log Out")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .padding(.horizontal, 40)
                        } else {
                            Button {
                                loginService.login()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.circle.fill")
                                        .font(.title3)
                                    Text("Log In")
                                        .font(.headline)
                                }
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.green)
                                )
                                .padding(.horizontal, 40)
                            }
                        }
                    }

                    if let url = lastRecordingURL {
                        VStack(spacing: 8) {
                            Text("Last Recording")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            Text(url.lastPathComponent)
                                .font(.caption)
                                .foregroundStyle(.cyan)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.08))
                                )
                        }
                    }
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                loginService.loadCurrentAccount()
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
