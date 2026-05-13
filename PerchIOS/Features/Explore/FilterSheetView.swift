import SwiftUI

struct FilterSheetView: View {
    @Binding var filters: SpotFilterState

    var body: some View {
        NavigationStack {
            Form {
                Section("Scope") {
                    Toggle("Nearby only", isOn: $filters.nearbyOnly)
                    Toggle("Favorites only", isOn: $filters.favoritesOnly)
                }

                Section("Find the right pause") {
                    Toggle("Quiet spots", isOn: $filters.quietOnly)
                    Toggle("Shaded or partially shaded", isOn: $filters.shadedOnly)
                    Toggle("Good for sunset", isOn: $filters.sunsetOnly)
                    Toggle("Accessible spots", isOn: $filters.accessibleOnly)
                    Toggle("Low-effort access", isOn: $filters.easyAccessOnly)
                }

                if filters.hasActiveFilters {
                    Section {
                        Button("Reset filters", role: .destructive) {
                            filters = .default
                        }
                    }
                }
            }
            .navigationTitle("Filters")
        }
        .presentationDetents([.medium, .large])
    }
}
