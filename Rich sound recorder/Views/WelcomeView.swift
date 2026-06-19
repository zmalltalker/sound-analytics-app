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
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            heroSection
                .padding(.horizontal, RSRSpace.screen)

            Spacer(minLength: 0)

            signInSection
                .padding(.horizontal, RSRSpace.screen)
                .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RSR.canvas.ignoresSafeArea())
    }

    private var heroSection: some View {
        VStack(spacing: RSRSpace.lg) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(RSR.accentTileGradient)
                .frame(width: 144, height: 144)
                .overlay {
                    Image(systemName: "waveform")
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .rsrShadow(.accentLift)

            VStack(spacing: RSRSpace.sm) {
                Text("Resonyx mobile")
                    .font(.rsrLargeTitle)
                    .tracking(RSRTracking.largeTitle)
                    .foregroundStyle(RSR.labelPrimary)
                    .multilineTextAlignment(.center)

                Text("Industrial sound intelligence by Expert Analytics")
                    .font(.rsrBody)
                    .foregroundStyle(RSR.labelSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var signInSection: some View {
        VStack(spacing: RSRSpace.md) {
            Button {
                loginService.login()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Sign in with Microsoft")
                        .font(.rsrHeadline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(RSR.accentGradient)
                .clipShape(RoundedRectangle(cornerRadius: RSRRadius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: RSRRadius.control, style: .continuous)
                        .strokeBorder(.white.opacity(0.4), lineWidth: 0.5)
                )
                .rsrShadow(.accentLift)
            }
            .buttonStyle(.plain)

            Text("Use your Microsoft account to access projects, labels, and training workflows.")
                .font(.rsrCaption)
                .foregroundStyle(RSR.labelTertiary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    WelcomeView(loginService: AuthenticationService())
}
