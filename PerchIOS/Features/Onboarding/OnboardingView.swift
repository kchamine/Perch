import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var locationManager: LocationManager

    @State private var currentPage = 0

    var body: some View {
        ZStack {
            PerchTheme.background.ignoresSafeArea()

            if currentPage == 0 {
                introPage
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            } else {
                locationPage
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentPage)
    }

    private var introPage: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [PerchTheme.accent, PerchTheme.primary.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)

                    Image(systemName: "leaf.fill")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(PerchTheme.primary)
                }

                VStack(spacing: 14) {
                    Text("Find a place\nworth a pause.")
                        .font(PerchTheme.headline(40))
                        .foregroundStyle(PerchTheme.primary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)

                    Text("Perch helps you discover real, public spots — benches, overlooks, waterfront seats — that are actually worth sitting down for.")
                        .font(.body)
                        .foregroundStyle(PerchTheme.textMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .padding(.horizontal, 8)
                }
            }
            .padding(.horizontal, 36)

            Spacer()

            Button {
                withAnimation { currentPage = 1 }
            } label: {
                HStack(spacing: 10) {
                    Text("Continue")
                    Image(systemName: "arrow.right")
                }
                .font(PerchTheme.label(13, weight: .bold))
                .textCase(.uppercase)
                .tracking(1.2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(colors: [PerchTheme.primary, PerchTheme.primarySoft], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Capsule()
                )
                .foregroundStyle(.white)
                .shadow(color: PerchTheme.primary.opacity(0.22), radius: 16, y: 8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
            .padding(.bottom, 56)
        }
    }

    private var locationPage: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [PerchTheme.accent, PerchTheme.primary.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)

                    Image(systemName: "location.fill")
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundStyle(PerchTheme.primary)
                }

                VStack(spacing: 14) {
                    Text("Location helps Perch show what's nearby.")
                        .font(PerchTheme.headline(36))
                        .foregroundStyle(PerchTheme.primary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)

                    Text("When you share your location, Perch can sort spots by distance, show the nearest benches, and help you find somewhere great right now.")
                        .font(.body)
                        .foregroundStyle(PerchTheme.textMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .padding(.horizontal, 8)
                }
            }
            .padding(.horizontal, 36)

            Spacer()

            VStack(spacing: 14) {
                Button {
                    locationManager.requestIfNeeded()
                    appState.completeOnboarding()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "location.fill")
                        Text("Allow Location")
                    }
                    .font(PerchTheme.label(13, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(colors: [PerchTheme.primary, PerchTheme.primarySoft], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Capsule()
                    )
                    .foregroundStyle(.white)
                    .shadow(color: PerchTheme.primary.opacity(0.22), radius: 16, y: 8)
                }
                .buttonStyle(.plain)

                Button {
                    appState.completeOnboarding()
                } label: {
                    Text("Skip for now")
                        .font(PerchTheme.label(12, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(PerchTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 56)
        }
    }
}
