import PhotosUI
import SwiftUI
import UIKit

struct AddSpotView: View {
    let editingSpot: Spot?

    init(editingSpot: Spot? = nil) {
        self.editingSpot = editingSpot
    }

    @EnvironmentObject private var store: SpotStore
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var subtitle = ""
    @State private var notes = ""
    @State private var spotType: SpotType = .bench
    @State private var seatingType: SeatingType = .bench
    @State private var hasSeating = true
    @State private var shadeLevel: ShadeLevel = .partial
    @State private var noiseLevel: NoiseLevel = .quiet
    @State private var crowdLevel: CrowdLevel = .low
    @State private var viewType: ViewType = .park
    @State private var bestTime: BestTime = .afternoon
    @State private var accessibility: AccessibilityLevel = .stepFree
    @State private var accessEffort: AccessEffort = .easy
    @State private var comfortRating = 4.0
    @State private var scenicRating = 4.0
    @State private var publicAccessConfirmed = true
    @State private var latitude = 37.8000
    @State private var longitude = -122.4330
    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedUIImage: UIImage?
    @State private var cropSourceImage: UIImage?
    @State private var photoLoadID = UUID()
    @State private var photoPickerSessionID = UUID()
    @State private var saveStateMessage: String?
    @State private var isSaving = false
    @State private var isLoadingPhoto = false
    @State private var isShowingCropper = false
    @State private var existingPhotoPath: String?
    @State private var newPhotoSelected = false
    @FocusState private var focusedField: Field?

    private let imageStore = ImageStore()

    private enum Field: Hashable {
        case name
        case subtitle
        case notes
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PerchTopBar(leadingSystemImage: nil, title: "Perch", trailingSystemImage: nil)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(editingSpot == nil ? "Post a Perch" : "Edit Perch")
                            .font(PerchTheme.headline(40))
                            .foregroundStyle(PerchTheme.primary)
                        Text(editingSpot == nil
                             ? "Share a real public place someone can actually sit, pause, and trust."
                             : "Update any detail below — your reviews and saves stay attached.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PerchTheme.textMuted)
                            .lineSpacing(3)
                        TagFlowLayout(spacing: 8, rowSpacing: 8) {
                            InlineTag(icon: "1.circle.fill", text: "Photo")
                            InlineTag(icon: "2.circle.fill", text: "Basics")
                            InlineTag(icon: "3.circle.fill", text: "Trust")
                            InlineTag(icon: "4.circle.fill", text: "Preview")
                        }
                    }
                    .padding(.horizontal, 18)

                    photoSection
                        .padding(.horizontal, 18)

                    editorialBlock(title: "Basics") {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Keep this tight. The goal is to help someone decide whether this perch is worth a real visit.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            editorialField(label: "Perch name", text: $name, prompt: "Quiet Green Bench", field: .name)
                            editorialField(label: "Why it is worth posting", text: $subtitle, prompt: "Soft light, quiet benches, coffee nearby", field: .subtitle)
                        }
                    }

                    editorialBlock(title: "Category") {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("What kind of public perch is this, at its core?")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            let columns = [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ]

                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(spotTypeOptions, id: \.self) { type in
                                    categoryButton(type: type, selected: spotType == type) {
                                        spotType = type
                                    }
                                }
                            }
                        }
                    }

                    editorialBlock(title: "The vibe") {
                        VStack(alignment: .leading, spacing: 18) {
                            Text("Describe how the place usually feels when someone shows up to sit, pause, and enjoy it.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            vibeSelectorRow(title: "Noise", selection: $noiseLevel, options: NoiseLevel.allCases)
                            vibeSelectorRow(title: "Light", selection: $shadeLevel, options: ShadeLevel.allCases)
                            vibeSelectorRow(title: "Best time", selection: $bestTime, options: bestTimeOptions)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                selectionCard(title: "Primary view", value: viewType.label) {
                                    Picker("Primary view", selection: $viewType) {
                                        ForEach(viewTypeOptions) { Text($0.label).tag($0) }
                                    }
                                }
                                selectionCard(title: "Busyness", value: crowdLevel.label) {
                                    Picker("Busyness", selection: $crowdLevel) {
                                        ForEach(CrowdLevel.allCases) { Text($0.label).tag($0) }
                                    }
                                }
                            }
                        }
                    }

                    editorialBlock(title: "Signals") {
                        VStack(alignment: .leading, spacing: 18) {
                            Text("These are the trust signals that make a perch actually useful once someone gets there.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                selectionCard(title: "Seating", value: seatingType.label) {
                                    Picker("Seating", selection: $seatingType) {
                                        ForEach(SeatingType.allCases) { Text($0.label).tag($0) }
                                    }
                                }
                                selectionCard(title: "Getting there", value: accessEffort.label) {
                                    Picker("Getting there", selection: $accessEffort) {
                                        ForEach(AccessEffort.allCases) { Text($0.label).tag($0) }
                                    }
                                }
                                selectionCard(title: "Accessibility", value: accessibility.label) {
                                    Picker("Accessibility", selection: $accessibility) {
                                        ForEach(AccessibilityLevel.allCases) { Text($0.label).tag($0) }
                                    }
                                }
                            }

                            ratingRow(title: "Comfort", subtitle: "Would you actually want to linger here for a while?", value: Int(comfortRating), binding: $comfortRating)
                            ratingRow(title: "Scenic quality", subtitle: "How rewarding is the setting once you're in the seat?", value: Int(scenicRating), binding: $scenicRating)

                            Toggle(isOn: $publicAccessConfirmed) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Public access confirmed")
                                        .font(.headline)
                                    Text("Only post places another person can really use without special access.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .toggleStyle(.switch)

                            Toggle(isOn: $hasSeating) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Actual place to sit")
                                        .font(.headline)
                                    Text("Turn this off if the perch is more of a pause point, ledge, or leaning stop than a true seat.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .toggleStyle(.switch)
                        }
                    }

                    editorialBlock(title: "Location & notes") {
                        VStack(spacing: 18) {
                            LocationPickerView(
                                latitude: $latitude,
                                longitude: $longitude,
                                userCoordinate: locationManager.location?.coordinate
                            )
                            .frame(minHeight: 220)

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Notes")
                                    .font(PerchTheme.label(10, weight: .bold))
                                    .textCase(.uppercase)
                                    .tracking(1)
                                    .foregroundStyle(.secondary)
                                TextField("Anything useful to remember about this spot?", text: $notes, axis: .vertical)
                                    .focused($focusedField, equals: .notes)
                                    .lineLimit(4...7)
                                    .padding(16)
                                    .background(PerchTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            }
                        }
                    }

                    editorialBlock(title: "Preview") {
                        postPreviewCard
                    }

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                    }

                    if let saveStateMessage {
                        Text(saveStateMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                    }

                    Button {
                        Task { await saveSpot() }
                    } label: {
                        HStack(spacing: 10) {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isSaving ? (editingSpot == nil ? "Posting..." : "Saving...") : (editingSpot == nil ? "Post Perch" : "Save Changes"))
                            Image(systemName: "paperplane.fill")
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
                    .padding(.horizontal, 20)
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.6)

                    Text("By posting, you agree to keep Perch useful, public, and grounded in real places.")
                        .font(PerchTheme.label(9, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(1.1)
                        .foregroundStyle(.secondary.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 120)
                }
            }
            .background(PerchTheme.background.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if let spot = editingSpot {
                    prefillForEditing(spot)
                } else if let coordinate = locationManager.location?.coordinate {
                    latitude = coordinate.latitude
                    longitude = coordinate.longitude
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                let loadID = UUID()
                photoLoadID = loadID
                Task { await loadPreview(for: newItem, loadID: loadID) }
            }
            .sheet(isPresented: $isShowingCropper, onDismiss: {
                cropSourceImage = nil
            }) {
                if let cropSourceImage {
                    PhotoCropperView(
                        sourceImage: cropSourceImage,
                        aspectRatio: 1.38
                    ) { croppedImage in
                        applySelectedImage(croppedImage)
                    }
                }
            }
        }
    }

    private var postPreviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(PerchTheme.accent.opacity(0.5))
                        .frame(width: 76, height: 92)
                    if let selectedUIImage {
                        Image(uiImage: selectedUIImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 76, height: 92)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    } else {
                        Image(systemName: spotType.icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(PerchTheme.primary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(trimmedName.isEmpty ? "Your perch name" : trimmedName)
                        .font(PerchTheme.headline(22))
                        .foregroundStyle(PerchTheme.primary)
                        .lineLimit(1)
                    Text(trimmedSubtitle.isEmpty ? "A short reason to go will appear here." : trimmedSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(PerchTheme.textMuted)
                        .lineLimit(2)
                    TagFlowLayout(spacing: 7, rowSpacing: 7) {
                        InlineTag(icon: spotType.icon, text: spotType.label)
                        InlineTag(icon: "star.fill", text: "\(Int(scenicRating)).0")
                        InlineTag(text: publicAccessConfirmed ? "Public access" : "Access unconfirmed", tint: publicAccessConfirmed ? .green : .orange)
                    }
                }
            }

            Divider().opacity(0.4)

            VStack(alignment: .leading, spacing: 8) {
                previewCheckRow(isReady: !trimmedName.isEmpty, text: "Named clearly")
                previewCheckRow(isReady: !trimmedSubtitle.isEmpty, text: "Reason to visit is clear")
                previewCheckRow(isReady: publicAccessConfirmed, text: "Public access confirmed")
                previewCheckRow(isReady: hasPhoto, text: hasPhoto ? "Photo ready" : "Photo required before posting")
            }
        }
        .padding(16)
        .background(PerchTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(PerchTheme.border, lineWidth: 1)
        )
    }

    private func previewCheckRow(isReady: Bool, text: String) -> some View {
        Label(text, systemImage: isReady ? "checkmark.circle.fill" : "circle")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isReady ? PerchTheme.primary : PerchTheme.textMuted)
    }

    private var photoSection: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(PerchTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(PerchTheme.border, lineWidth: 1)
                    )
                    .frame(height: 280)

                if let selectedUIImage {
                    Image(uiImage: selectedUIImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 280)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .overlay(alignment: .bottomTrailing) {
                            Button(role: .destructive) {
                                clearSelectedPhoto()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(12)
                                    .background(Color.black.opacity(0.32), in: Circle())
                            }
                            .padding(16)
                        }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(PerchTheme.primary)
                        Text("Add a photo")
                            .font(PerchTheme.headline(28))
                            .foregroundStyle(PerchTheme.primary)
                        Text(isLoadingPhoto ? "Loading photo..." : "Required — every posted perch needs a real photo")
                            .font(PerchTheme.label(11, weight: .bold))
                            .textCase(.uppercase)
                            .tracking(1.1)
                            .foregroundStyle(.secondary)
                        if isLoadingPhoto {
                            ProgressView()
                                .tint(PerchTheme.primary)
                                .padding(.top, 6)
                        }
                    }
                }
            }
        }
        .id(photoPickerSessionID)
        .disabled(isLoadingPhoto)
    }

    private func editorialBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(PerchTheme.headline(28))
                .foregroundStyle(PerchTheme.primary)
            content()
        }
        .padding(20)
        .perchGlassCard()
        .padding(.horizontal, 20)
    }

    private func editorialField(label: String, text: Binding<String>, prompt: String, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(PerchTheme.label(10, weight: .bold))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(.secondary)
            TextField(prompt, text: text, axis: .vertical)
                .focused($focusedField, equals: field)
                .font(.title3)
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.18))
                        .frame(height: 1)
                }
        }
    }

    private var spotTypeOptions: [SpotType] {
        [.bench, .overlook, .waterfront, .courtyard, .picnicSeat, .plazaSeat, .parkEdge]
    }

    private var bestTimeOptions: [BestTime] {
        [.morning, .afternoon, .sunset, .evening]
    }

    private var viewTypeOptions: [ViewType] {
        [.water, .park, .skyline, .hill, .street, .mixed]
    }

    private func categoryButton(type: SpotType, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .center, spacing: 12) {
                Image(systemName: type.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .center)
                VStack(alignment: .center, spacing: 6) {
                    Text(type.label)
                        .font(PerchTheme.label(11, weight: .bold))
                        .textCase(.uppercase)
                        .multilineTextAlignment(.center)
                    Text(type.prompt)
                        .font(.caption)
                        .foregroundStyle(selected ? PerchTheme.controlTextOnStrong.opacity(0.88) : PerchTheme.textMuted)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .center)
            .padding(16)
            .background(selected ? PerchTheme.controlFillStrong : PerchTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(selected ? PerchTheme.primarySoft.opacity(0.75) : PerchTheme.border, lineWidth: 1)
            )
            .foregroundStyle(selected ? PerchTheme.controlTextOnStrong : PerchTheme.primary)
        }
        .buttonStyle(.plain)
    }

    private func vibeChip(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(active ? PerchTheme.controlFillStrong : PerchTheme.controlFill, in: Capsule())
                .overlay(
                    Capsule().stroke(active ? PerchTheme.primarySoft.opacity(0.75) : PerchTheme.border, lineWidth: 1)
                )
                .foregroundStyle(active ? PerchTheme.controlTextOnStrong : PerchTheme.primary)
        }
        .buttonStyle(.plain)
    }

    private func vibeSelectorRow<Option: Identifiable>(title: String, selection: Binding<Option>, options: [Option]) -> some View where Option: Hashable, Option: CustomStringConvertible {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(PerchTheme.label(10, weight: .bold))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(.secondary)
            TagFlowLayout(spacing: 10, rowSpacing: 12) {
                ForEach(options, id: \.self) { option in
                    vibeChip(option.description, active: selection.wrappedValue == option) {
                        selection.wrappedValue = option
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func selectionCard<PickerContent: View>(title: String, value: String, @ViewBuilder picker: () -> PickerContent) -> some View {
        Menu {
            picker()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(PerchTheme.label(10, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(.secondary)
                HStack {
                    Text(value)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PerchTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(PerchTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func ratingRow(title: String, subtitle: String, value: Int, binding: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(value)/5")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Slider(value: binding, in: 1...5, step: 1)
                .tint(PerchTheme.primary)
        }
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedSubtitle: String { subtitle.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canSave: Bool {
        !isSaving && validationMessage == nil
    }

    private var hasPhoto: Bool { selectedUIImage != nil || existingPhotoPath != nil }

    private var validationMessage: String? {
        if trimmedName.isEmpty { return "Add a perch name before posting." }
        if trimmedSubtitle.isEmpty { return "Add a short reason to go so the post feels discoverable later." }
        if !hasPhoto { return "Add a real photo of this perch before posting." }
        if !publicAccessConfirmed { return "Confirm public access before posting so Perch stays trustworthy." }
        return nil
    }

    private func loadPreview(for item: PhotosPickerItem?, loadID: UUID) async {
        guard let item else { return }

        await MainActor.run {
            isLoadingPhoto = true
            saveStateMessage = nil
        }

        do {
            if let data = try await item.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                await MainActor.run {
                    guard photoLoadID == loadID else { return }
                    let normalized = uiImage.downsampled(toFit: 2048).normalizedImage()
                    cropSourceImage = normalized
                    pickerItem = nil
                    isLoadingPhoto = false
                    focusedField = nil
                    isShowingCropper = true
                }
            } else {
                await MainActor.run {
                    guard photoLoadID == loadID else { return }
                    pickerItem = nil
                    isLoadingPhoto = false
                    saveStateMessage = "Couldn't load that photo."
                }
            }
        } catch {
            await MainActor.run {
                guard photoLoadID == loadID else { return }
                pickerItem = nil
                isLoadingPhoto = false
                saveStateMessage = error.localizedDescription
            }
        }
    }

    private func saveSpot() async {
        guard canSave else { return }

        isSaving = true
        focusedField = nil
        defer { isSaving = false }

        do {
            if let original = editingSpot {
                let photoPath: String?
                if newPhotoSelected {
                    photoPath = try imageStore.saveImage(selectedUIImage)
                    imageStore.deleteImage(atPath: existingPhotoPath)
                } else {
                    photoPath = existingPhotoPath
                }
                let updated = Spot(
                    id: original.id,
                    name: trimmedName,
                    subtitle: trimmedSubtitle,
                    latitude: latitude,
                    longitude: longitude,
                    photoName: nil,
                    userPhotoPath: photoPath,
                    spotType: spotType,
                    seatingType: seatingType,
                    hasSeating: hasSeating,
                    shadeLevel: shadeLevel,
                    noiseLevel: noiseLevel,
                    crowdLevel: crowdLevel,
                    viewType: viewType,
                    bestTime: bestTime,
                    accessibility: accessibility,
                    accessEffort: accessEffort,
                    comfortRating: Int(comfortRating),
                    scenicRating: Int(scenicRating),
                    publicAccessConfirmed: publicAccessConfirmed,
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    lastConfirmed: .now
                )
                store.update(updated)
                dismiss()
            } else {
                let savedPath = try imageStore.saveImage(selectedUIImage)
                let spot = Spot(
                    id: UUID(),
                    name: trimmedName,
                    subtitle: trimmedSubtitle,
                    latitude: latitude,
                    longitude: longitude,
                    photoName: nil,
                    userPhotoPath: savedPath,
                    spotType: spotType,
                    seatingType: seatingType,
                    hasSeating: hasSeating,
                    shadeLevel: shadeLevel,
                    noiseLevel: noiseLevel,
                    crowdLevel: crowdLevel,
                    viewType: viewType,
                    bestTime: bestTime,
                    accessibility: accessibility,
                    accessEffort: accessEffort,
                    comfortRating: Int(comfortRating),
                    scenicRating: Int(scenicRating),
                    publicAccessConfirmed: publicAccessConfirmed,
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    lastConfirmed: .now
                )
                store.addSpot(spot)
                resetForm(keepingLocation: true)
                saveStateMessage = nil
                appState.revealInExplore(spot)
            }
        } catch {
            saveStateMessage = error.localizedDescription
        }
    }

    private func prefillForEditing(_ spot: Spot) {
        name = spot.name
        subtitle = spot.subtitle
        notes = spot.notes
        spotType = spot.spotType
        seatingType = spot.seatingType
        hasSeating = spot.hasSeating
        shadeLevel = spot.shadeLevel
        noiseLevel = spot.noiseLevel
        crowdLevel = spot.crowdLevel
        viewType = spot.viewType
        bestTime = spot.bestTime
        accessibility = spot.accessibility
        accessEffort = spot.accessEffort
        comfortRating = Double(spot.comfortRating)
        scenicRating = Double(spot.scenicRating)
        publicAccessConfirmed = spot.publicAccessConfirmed
        latitude = spot.latitude
        longitude = spot.longitude
        existingPhotoPath = spot.userPhotoPath
        if let path = spot.userPhotoPath,
           let data = imageStore.imageData(for: path),
           let image = UIImage(data: data) {
            selectedUIImage = image
        }
    }

    private func resetForm(keepingLocation: Bool) {
        focusedField = nil
        name = ""
        subtitle = ""
        notes = ""
        spotType = .bench
        seatingType = .bench
        hasSeating = true
        shadeLevel = .partial
        noiseLevel = .quiet
        crowdLevel = .low
        viewType = .park
        bestTime = .afternoon
        accessibility = .stepFree
        accessEffort = .easy
        comfortRating = 4
        scenicRating = 4
        publicAccessConfirmed = true
        resetPhotoSelectionState()
        if !keepingLocation {
            latitude = 37.8000
            longitude = -122.4330
        }
    }

    private func applySelectedImage(_ image: UIImage) {
        selectedUIImage = image.normalizedImage()
        newPhotoSelected = true
        pickerItem = nil
        cropSourceImage = nil
        isShowingCropper = false
        isLoadingPhoto = false
        saveStateMessage = nil
    }

    private func clearSelectedPhoto() {
        resetPhotoSelectionState()
        saveStateMessage = nil
    }

    private func resetPhotoSelectionState() {
        photoLoadID = UUID()
        photoPickerSessionID = UUID()
        pickerItem = nil
        selectedUIImage = nil
        cropSourceImage = nil
        isShowingCropper = false
        isLoadingPhoto = false
    }
}
