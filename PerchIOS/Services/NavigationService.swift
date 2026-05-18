import Foundation
import MapKit
import UIKit

enum NavigationService {
    enum OpenResult: Equatable {
        case opened(MapsAppPreference)
        case fellBackToAppleMaps
    }

    @MainActor
    @discardableResult
    static func openDirections(for spot: Spot) -> OpenResult {
        openDirections(for: spot, using: .appleMaps)
    }

    @MainActor
    @discardableResult
    static func openDirections(for spot: Spot, using preference: MapsAppPreference) -> OpenResult {
        switch preference {
        case .appleMaps:
            openAppleMaps(for: spot)
            return .opened(.appleMaps)
        case .googleMaps:
            guard let url = googleMapsURL(for: spot),
                  UIApplication.shared.canOpenURL(url) else {
                openAppleMaps(for: spot)
                return .fellBackToAppleMaps
            }

            UIApplication.shared.open(url)
            return .opened(.googleMaps)
        }
    }

    private static func openAppleMaps(for spot: Spot) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: spot.coordinate))
        item.name = spot.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }

    private static func googleMapsURL(for spot: Spot) -> URL? {
        URL(string: "comgooglemaps://?daddr=\(spot.latitude),\(spot.longitude)&directionsmode=walking")
    }
}
