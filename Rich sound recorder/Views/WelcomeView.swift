//
//  WelcomeView.swift
//  Rich sound recorder
//
//  Created by Marius Mathiesen on 17/03/2026.
//

import SwiftUI

struct WelcomeView: View {
    let loginService: AuthenticationService

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(.cyan)

                    Text("Rich Sound Recorder")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("High-quality audio recording with real-time frequency analysis")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        loginService.login()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.circle.fill")
                                .font(.title3)
                            Text("Sign In with Microsoft")
                                .font(.headline)
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.cyan)
                        )
                        .padding(.horizontal, 40)
                    }

                    Text("Sign in to start recording and analyzing audio")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.bottom, 60)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    WelcomeView(loginService: AuthenticationService())
}
