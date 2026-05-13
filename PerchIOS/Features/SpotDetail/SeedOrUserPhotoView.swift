import SwiftUI
import UIKit

struct SeedOrUserPhotoView: View {
    enum Style {
        case editorial
        case photoOnly
        case photoFit
    }

    let spot: Spot
    var style: Style = .editorial

    @State private var displayImage: UIImage?
    @State private var isLoadingUserImage = false

    var imageAspectRatio: CGFloat? {
        guard let displayImage, displayImage.size.height > 0 else { return nil }
        return displayImage.size.width / displayImage.size.height
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
        .task(id: spot.userPhotoPath) {
            await loadUserImage()
        }
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

                Spacer(minLength: displayImage == nil ? 0 : 8)

                if let displayImage {
                    Image(uiImage: displayImage)
                        .resizable()
                        .scaledToFill()
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

            if isLoadingUserImage {
                ProgressView()
                    .tint(.white)
                    .padding()
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
    }

    private var photoOnlyBody: some View {
        ZStack {
            if let displayImage {
                Image(uiImage: displayImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                seedGradient
            }

            if isLoadingUserImage {
                ProgressView()
                    .tint(.white)
                    .padding()
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
    }

    private var photoFitBody: some View {
        ZStack {
            Color.black.opacity(displayImage == nil ? 0 : 1)

            if let displayImage {
                Image(uiImage: displayImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if isLoadingUserImage {
                ProgressView()
                    .tint(.white)
                    .padding()
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
    }

    private func loadUserImage() async {
        guard let path = spot.userPhotoPath else {
            isLoadingUserImage = false
            displayImage = nil
            return
        }

        isLoadingUserImage = true
        let image: UIImage? = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let data = FileManager.default.contents(atPath: path) else { return nil }
            return UIImage(data: data)
        }.value
        displayImage = image
        isLoadingUserImage = false
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
