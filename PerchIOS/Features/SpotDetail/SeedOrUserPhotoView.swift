import SwiftUI

struct SeedOrUserPhotoView: View {
    enum Style {
        case editorial
        case photoOnly
        case photoFit
    }

    let spot: Spot
    var style: Style = .editorial

    var imageAspectRatio: CGFloat? {
        nil
    }

    private var photoURL: URL? {
        guard let value = spot.photoURL else { return nil }
        return URL(string: value)
    }

    var body: some View {
        Group {
            switch style {
            case .editorial:
                editorialBody
            case .photoOnly:
                photoOnlyBody
            case .photoFit:
                photoFitBody
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var editorialBody: some View {
        ZStack {
            seedGradient
                .overlay {
                    LinearGradient(
                        colors: [.white.opacity(0.04), .black.opacity(0.18)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Image(systemName: gradientSymbol(for: spot.viewType))
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.24))
                        .padding(14)
                }

                Spacer(minLength: photoURL == nil ? 0 : 8)

                if let photoURL {
                    remotePhoto(url: photoURL, mode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 138)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(spot.viewType.label)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                        Text(spot.name)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    Spacer(minLength: 0)
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.18)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }

    private var photoOnlyBody: some View {
        ZStack {
            if let photoURL {
                remotePhoto(url: photoURL, mode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                seedGradient
            }
        }
    }

    private var photoFitBody: some View {
        ZStack {
            Color.black.opacity(photoURL == nil ? 0 : 1)

            if let photoURL {
                remotePhoto(url: photoURL, mode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private enum RemotePhotoMode {
        case fill
        case fit
    }

    private func remotePhoto(url: URL, mode: RemotePhotoMode) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                switch mode {
                case .fill:
                    image.resizable().scaledToFill()
                case .fit:
                    image.resizable().scaledToFit()
                }
            case .empty:
                ProgressView()
                    .tint(.white)
                    .padding()
                    .background(.ultraThinMaterial, in: Circle())
            case .failure:
                seedGradient
            @unknown default:
                seedGradient
            }
        }
    }

    private var seedGradient: some View {
        LinearGradient(colors: gradientColors(for: spot.seedPhotoKey), startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(alignment: .topTrailing) {
                Image(systemName: gradientSymbol(for: spot.viewType))
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.28))
                    .padding()
            }
    }

    private func gradientColors(for key: SeedPhotoKey?) -> [Color] {
        switch key {
        case .ferryLanding: [.blue, .mint]
        case .eucalyptusBench: [.green, .teal]
        case .cityOutlook: [.indigo, .purple]
        case .roseGarden: [.pink, .orange]
        case .baySteps: [.cyan, .blue]
        case .pointBench: [.mint, .green]
        case .libraryPlaza: [.gray, .blue]
        case .marinaSeat: [.teal, .cyan]
        case .hillRest: [.brown, .green]
        case .quietGreen: [.green, .mint]
        case .waterfrontLedge: [.indigo, .cyan]
        case .sunsetTerrace: [.orange, .pink]
        case .centralParkBench: [.green, .brown]
        case .highLineLedge: [.gray, .green]
        case .brooklynBridgePark: [.blue, .indigo]
        case .griffithOverlook: [.orange, .brown]
        case .veniceBeachPerch: [.cyan, .orange]
        case .echoLakeSeat: [.teal, .green]
        case .kerryParkBench: [.mint, .teal]
        case .waterfrontPier: [.blue, .cyan]
        case .discoveryParkEdge: [.green, .blue]
        case .none: [.gray, .blue]
        }
    }

    private func gradientSymbol(for viewType: ViewType) -> String {
        switch viewType {
        case .water: "water.waves"
        case .skyline: "building.2"
        case .park: "leaf"
        case .hill: "mountain.2"
        case .street: "tram.fill"
        case .mixed: "sparkles"
        }
    }
}
