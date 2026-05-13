import SwiftUI
import UIKit

struct PhotoCropperView: View {
    let sourceImage: UIImage
    let aspectRatio: CGFloat
    let onUseCrop: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero
    @State private var currentCropSize: CGSize = .zero

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let cropSize = cropFrameSize(in: geometry.size)

                VStack(spacing: 20) {
                    Text("Adjust the photo so this frame matches what Perch will save.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    ZStack {
                        Color.black.ignoresSafeArea()

                        cropCanvas(cropSize: cropSize)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    VStack(spacing: 12) {
                        Text("Drag to reframe within the crop area.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("Reset framing") {
                            resetState(for: cropSize)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .background(Color(uiColor: .systemBackground))
                .onAppear {
                    currentCropSize = cropSize
                    resetState(for: cropSize)
                }
                .onChange(of: cropSize) { _, newCropSize in
                    currentCropSize = newCropSize
                    resetState(for: newCropSize)
                }
            }
            .navigationTitle("Crop Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Crop") {
                        onUseCrop(renderCroppedImage(cropSize: currentCropSize))
                        dismiss()
                    }
                }
            }
        }
    }

    private func cropCanvas(cropSize: CGSize) -> some View {
        let imageSize = fittedImageSize(for: cropSize)

        return ZStack {
            Color.black

            Image(uiImage: sourceImage)
                .resizable()
                .frame(
                    width: imageSize.width,
                    height: imageSize.height
                )
                .offset(offset)
                .gesture(dragGesture(for: cropSize))

            cropMask(cropSize: cropSize)

            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(.white.opacity(0.9), lineWidth: 2)
                .frame(width: cropSize.width, height: cropSize.height)
                .allowsHitTesting(false)
        }
    }

    private func dragGesture(for cropSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                offset = clampedOffset(
                    CGSize(
                        width: baseOffset.width + value.translation.width,
                        height: baseOffset.height + value.translation.height
                    ),
                    cropSize: cropSize
                )
            }
            .onEnded { _ in
                baseOffset = offset
            }
    }

    private func cropMask(cropSize: CGSize) -> some View {
        Rectangle()
            .fill(.black.opacity(0.55))
            .mask {
                Rectangle()
                    .overlay {
                        RoundedRectangle(cornerRadius: 28)
                            .frame(width: cropSize.width, height: cropSize.height)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
            }
            .allowsHitTesting(false)
    }

    private func cropFrameSize(in availableSize: CGSize) -> CGSize {
        let horizontalPadding: CGFloat = 32
        let verticalPadding: CGFloat = 220
        let maxWidth = max(availableSize.width - horizontalPadding, 220)
        let maxHeight = max(availableSize.height - verticalPadding, 220)

        let widthFromHeight = maxHeight * aspectRatio
        let width = min(maxWidth, widthFromHeight)
        let height = width / aspectRatio
        return CGSize(width: width, height: height)
    }

    private func fittedImageSize(for cropSize: CGSize) -> CGSize {
        let sourceSize = sourcePixelSize
        guard sourceSize.width > 0, sourceSize.height > 0 else { return cropSize }
        let imageAspectRatio = sourceSize.width / sourceSize.height
        if imageAspectRatio > aspectRatio {
            return CGSize(width: cropSize.height * imageAspectRatio, height: cropSize.height)
        }
        return CGSize(width: cropSize.width, height: cropSize.width / imageAspectRatio)
    }

    private func clampedOffset(_ proposedOffset: CGSize, cropSize: CGSize) -> CGSize {
        let fittedSize = fittedImageSize(for: cropSize)
        let maxX = max((fittedSize.width - cropSize.width) / 2, 0)
        let maxY = max((fittedSize.height - cropSize.height) / 2, 0)

        return CGSize(
            width: min(max(proposedOffset.width, -maxX), maxX),
            height: min(max(proposedOffset.height, -maxY), maxY)
        )
    }

    private func resetState(for cropSize: CGSize) {
        offset = .zero
        baseOffset = .zero
    }

    private func renderCroppedImage(cropSize: CGSize) -> UIImage {
        let fittedSize = fittedImageSize(for: cropSize)
        let sourceSize = sourcePixelSize
        let displayScale = max(fittedSize.width / max(sourceSize.width, 1), fittedSize.height / max(sourceSize.height, 1))
        let imageOrigin = CGPoint(
            x: (cropSize.width - fittedSize.width) / 2 + offset.width,
            y: (cropSize.height - fittedSize.height) / 2 + offset.height
        )

        let cropRect = CGRect(
            x: max(-imageOrigin.x / displayScale, 0),
            y: max(-imageOrigin.y / displayScale, 0),
            width: min(cropSize.width / displayScale, sourceSize.width),
            height: min(cropSize.height / displayScale, sourceSize.height)
        )
        .intersection(CGRect(origin: .zero, size: sourceSize))
        .integral

        guard cropRect.width > 0, cropRect.height > 0 else {
            return sourceImage
        }
        guard let cgImage = sourceImage.cgImage?.cropping(to: cropRect) else {
            return sourceImage
        }

        let cropped = UIImage(cgImage: cgImage, scale: sourceImage.scale, orientation: .up)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1600, height: 1200))
        return renderer.image { _ in
            cropped.draw(in: CGRect(origin: .zero, size: CGSize(width: 1600, height: 1200)))
        }
    }

    private var sourcePixelSize: CGSize {
        if let cgImage = sourceImage.cgImage {
            return CGSize(width: cgImage.width, height: cgImage.height)
        }
        return CGSize(
            width: sourceImage.size.width * sourceImage.scale,
            height: sourceImage.size.height * sourceImage.scale
        )
    }
}

extension UIImage {
    /// Redraws the image in .up orientation. Uses scale=1.0 to avoid screen-scale
    /// multiplication that can OOM-crash on large source images (e.g. 4284×5712).
    func normalizedImage() -> UIImage {
        guard imageOrientation != .up else { return self }
        guard size.width > 0, size.height > 0 else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Scales the image down so its longest pixel side fits within maxDimension.
    /// Returns self unchanged if the image is already small enough.
    /// Uses size*scale (orientation-aware) rather than cgImage dimensions so that
    /// landscape images stored with a rotated cgImage are not stretched into the
    /// wrong-shaped canvas.
    func downsampled(toFit maxDimension: CGFloat) -> UIImage {
        let w = size.width * scale
        let h = size.height * scale
        guard w > 0, h > 0 else { return self }
        let longSide = max(w, h)
        guard longSide > maxDimension else { return self }
        let factor = maxDimension / longSide
        let targetSize = CGSize(width: (w * factor).rounded(), height: (h * factor).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
