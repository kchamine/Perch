import SwiftUI
import UIKit

enum PerchTheme {
    static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }

    static let background = dynamic(
        light: UIColor(red: 0.972, green: 0.976, blue: 0.980, alpha: 1),
        dark: UIColor(red: 0.070, green: 0.082, blue: 0.078, alpha: 1)
    )
    static let surface = dynamic(
        light: UIColor.white.withAlphaComponent(0.78),
        dark: UIColor(red: 0.125, green: 0.145, blue: 0.137, alpha: 0.90)
    )
    static let surfaceStrong = dynamic(
        light: UIColor.white.withAlphaComponent(0.92),
        dark: UIColor(red: 0.155, green: 0.176, blue: 0.165, alpha: 0.96)
    )
    static let primary = dynamic(
        light: UIColor(red: 0.086, green: 0.204, blue: 0.133, alpha: 1),
        dark: UIColor(red: 0.832, green: 0.941, blue: 0.863, alpha: 1)
    )
    static let primarySoft = dynamic(
        light: UIColor(red: 0.178, green: 0.294, blue: 0.216, alpha: 1),
        dark: UIColor(red: 0.549, green: 0.729, blue: 0.624, alpha: 1)
    )
    static let textPrimary = dynamic(
        light: UIColor(red: 0.112, green: 0.164, blue: 0.128, alpha: 1),
        dark: UIColor(red: 0.955, green: 0.975, blue: 0.963, alpha: 1)
    )
    static let accent = dynamic(
        light: UIColor(red: 0.847, green: 0.921, blue: 0.865, alpha: 1),
        dark: UIColor(red: 0.187, green: 0.255, blue: 0.224, alpha: 1)
    )
    static let textMuted = dynamic(
        light: UIColor(red: 0.329, green: 0.380, blue: 0.341, alpha: 1),
        dark: UIColor(red: 0.728, green: 0.784, blue: 0.748, alpha: 1)
    )
    static let border = dynamic(
        light: UIColor.white.withAlphaComponent(0.52),
        dark: UIColor.white.withAlphaComponent(0.12)
    )
    static let shadow = dynamic(
        light: UIColor.black.withAlphaComponent(0.08),
        dark: UIColor.black.withAlphaComponent(0.28)
    )
    static let cardMaterial = dynamic(
        light: UIColor.white.withAlphaComponent(0.66),
        dark: UIColor(red: 0.125, green: 0.145, blue: 0.137, alpha: 0.88)
    )
    static let chipFill = dynamic(
        light: UIColor.white.withAlphaComponent(0.55),
        dark: UIColor(red: 0.180, green: 0.205, blue: 0.193, alpha: 0.96)
    )
    static let heroScrim = dynamic(
        light: UIColor.black.withAlphaComponent(0.22),
        dark: UIColor.black.withAlphaComponent(0.48)
    )
    static let controlFill = dynamic(
        light: UIColor.white.withAlphaComponent(0.72),
        dark: UIColor(red: 0.215, green: 0.243, blue: 0.231, alpha: 0.98)
    )
    static let controlFillStrong = dynamic(
        light: UIColor(red: 0.086, green: 0.204, blue: 0.133, alpha: 1),
        dark: UIColor(red: 0.255, green: 0.335, blue: 0.290, alpha: 1)
    )
    static let controlTextOnStrong = dynamic(
        light: UIColor.white,
        dark: UIColor(red: 0.955, green: 0.975, blue: 0.963, alpha: 1)
    )
    static let iconOnLightControl = dynamic(
        light: UIColor(red: 0.086, green: 0.204, blue: 0.133, alpha: 1),
        dark: UIColor(red: 0.112, green: 0.164, blue: 0.128, alpha: 1)
    )

    static func headline(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func label(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

struct PerchGlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(PerchTheme.border, lineWidth: 1)
            )
            .shadow(color: PerchTheme.shadow, radius: 18, y: 10)
    }
}

extension View {
    func perchGlassCard() -> some View {
        modifier(PerchGlassCard())
    }
}

struct PerchShell<Content: View>: View {
    @EnvironmentObject private var appState: AppState
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(PerchTheme.background.ignoresSafeArea())

            PerchBottomNav(selectedTab: $appState.selectedTab)
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
        }
        .background(PerchTheme.background.ignoresSafeArea())
    }
}

struct PerchBottomNav: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 10) {
            navButton(tab: .explore, title: "Explore", systemImage: "location.magnifyingglass")
            navButton(tab: .addSpot, title: "Post", systemImage: "plus.circle.fill", isPrimary: true)
            navButton(tab: .saved, title: "Saved", systemImage: "bookmark")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(PerchTheme.surface, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(PerchTheme.border, lineWidth: 1)
        )
        .shadow(color: PerchTheme.shadow, radius: 18, y: 8)
    }

    private func navButton(tab: AppTab, title: String, systemImage: String, isPrimary: Bool = false) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: isPrimary ? 3 : 4) {
                Image(systemName: systemImage)
                    .font(.system(size: isPrimary ? 24 : 16, weight: .semibold))
                Text(title)
                    .font(PerchTheme.label(isPrimary ? 10 : 10, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(0.8)
            }
            .foregroundStyle(isSelected || isPrimary ? PerchTheme.controlTextOnStrong : PerchTheme.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, isPrimary ? 9 : 10)
            .background(isPrimary || isSelected ? PerchTheme.controlFillStrong : .clear, in: Capsule())
            .shadow(color: isPrimary ? PerchTheme.primary.opacity(0.18) : .clear, radius: 12, y: 5)
        }
        .buttonStyle(.plain)
    }
}

struct PerchTopBar: View {
    let leadingSystemImage: String?
    let title: String
    let trailingSystemImage: String?
    var onLeadingTap: (() -> Void)?
    var onTrailingTap: (() -> Void)?

    var body: some View {
        HStack {
            topButton(systemImage: leadingSystemImage, action: onLeadingTap)
            Spacer()
            Text(title)
                .font(PerchTheme.headline(28))
                .italic()
                .foregroundStyle(PerchTheme.primary)
            Spacer()
            topButton(systemImage: trailingSystemImage, action: onTrailingTap)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func topButton(systemImage: String?, action: (() -> Void)?) -> some View {
        if let systemImage {
            Button(action: { action?() }) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PerchTheme.primary)
                    .frame(width: 40, height: 40)
                    .background(PerchTheme.chipFill, in: Circle())
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(width: 40, height: 40)
        }
    }
}
