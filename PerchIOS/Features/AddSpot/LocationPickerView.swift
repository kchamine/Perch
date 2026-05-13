import CoreLocation
import MapKit
import SwiftUI

struct LocationPickerView: View {
    @Binding var latitude: Double
    @Binding var longitude: Double
    var userCoordinate: CLLocationCoordinate2D?

    @State private var cameraPosition: MapCameraPosition
    @State private var lastCameraCenter: CLLocationCoordinate2D

    init(latitude: Binding<Double>, longitude: Binding<Double>, userCoordinate: CLLocationCoordinate2D?) {
        _latitude = latitude
        _longitude = longitude
        self.userCoordinate = userCoordinate
        let start = CLLocationCoordinate2D(latitude: latitude.wrappedValue, longitude: longitude.wrappedValue)
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(center: start, span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03))))
        _lastCameraCenter = State(initialValue: start)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pan the map and use the center crosshair.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Map(position: $cameraPosition) {
                Marker("Selected spot", coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                    .tint(.green)
                if let userCoordinate {
                    Marker("Your location", systemImage: "location.fill", coordinate: userCoordinate)
                        .tint(.blue)
                }
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .onMapCameraChange { context in
                let center = context.region.center
                lastCameraCenter = center
                latitude = center.latitude
                longitude = center.longitude
            }
            .onAppear {
                syncCameraToSelection()
            }
            .onChange(of: latitude) { _, _ in
                syncCameraToSelection()
            }
            .onChange(of: longitude) { _, _ in
                syncCameraToSelection()
            }

            HStack {
                Text(String(format: "%.5f, %.5f", latitude, longitude))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                if let userCoordinate {
                    Button("Use my location") {
                        latitude = userCoordinate.latitude
                        longitude = userCoordinate.longitude
                        lastCameraCenter = userCoordinate
                        cameraPosition = .region(MKCoordinateRegion(center: userCoordinate, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func syncCameraToSelection() {
        let selected = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        guard selected.isMeaningfullyDifferent(from: lastCameraCenter) else { return }
        lastCameraCenter = selected
        cameraPosition = .region(MKCoordinateRegion(center: selected, span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)))
    }
}

private extension CLLocationCoordinate2D {
    func isMeaningfullyDifferent(from other: CLLocationCoordinate2D, threshold: Double = 0.0001) -> Bool {
        abs(latitude - other.latitude) > threshold || abs(longitude - other.longitude) > threshold
    }
}
