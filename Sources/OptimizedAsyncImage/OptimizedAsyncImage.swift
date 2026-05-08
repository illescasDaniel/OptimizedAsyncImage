import SwiftUI
import ImageIO

#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
#endif

// A helper to initialize a SwiftUI Image from our platform-agnostic PlatformImage
private extension Image {
	init(platformImage: PlatformImage) {
		#if canImport(UIKit)
		self.init(uiImage: platformImage)
		#elseif canImport(AppKit)
		self.init(nsImage: platformImage)
		#endif
	}
}

// MARK: - OptimizedAsyncImage View

/// A view that asynchronously loads, downsamples, and caches an image.
public struct OptimizedAsyncImage<Content: View>: View {
	private let url: URL?
	private let targetSize: CGSize
	private let scale: CGFloat
	private let transaction: Transaction
	@ViewBuilder private let content: (AsyncImagePhase) -> Content

	@State private var phase: AsyncImagePhase = .empty
	@Environment(\.displayScale) private var displayScale

	/// Initializes an OptimizedAsyncImage.
	/// - Parameters:
	///   - url: The URL of the image to display.
	///   - targetSize: The physical pixel size to downsample the image to.
	///   - scale: The scale to use for the image. Defaults to 1.0.
	///   - transaction: The transaction to use when the phase changes.
	///   - content: A closure that takes the load phase as an input and returns the view to display.
	public init(
		url: URL?,
		targetSize: CGSize,
		scale: CGFloat = 1.0,
		transaction: Transaction = Transaction(),
		@ViewBuilder content: @escaping (AsyncImagePhase) -> Content
	) {
		self.url = url
		self.targetSize = targetSize
		self.scale = scale
		self.transaction = transaction
		self.content = content
	}

	public var body: some View {
		content(phase)
			.task(id: url) {
				await loadAndDownsampleImage()
			}
	}

	private func loadAndDownsampleImage() async {
		guard let url = url else {
			phase = .empty
			return
		}

		let urlString = url.absoluteString
		let memoryCacheKey = "\(urlString)-\(targetSize.width)x\(targetSize.height)"

		// 1. Check Memory
		if let cachedImage = await ImageCache.shared.getMemoryImage(forKey: memoryCacheKey) {
			withAnimation(transaction.animation) {
				phase = .success(Image(platformImage: cachedImage))
			}
			return
		}

		do {
			let imageData: Data

			// 2. Check Disk
			if let diskData = await ImageCache.shared.getDiskData(for: urlString) {
				imageData = diskData
			} else {
				// 3. Check Network
				let (fetchedData, response) = try await URLSession.shared.data(from: url)
				guard let httpResponse = response as? HTTPURLResponse,
					  (200...299).contains(httpResponse.statusCode) else {
					throw URLError(.badServerResponse)
				}
				imageData = fetchedData
				await ImageCache.shared.saveToDisk(imageData, for: urlString)
			}

			// 4. Downsample
			let targetScale = displayScale
			let size = targetSize

			if let platformImage = await Task.detached(operation: {
				downsample(imageData: imageData, to: size, scale: targetScale)
			}).value {

				await ImageCache.shared.saveToMemory(platformImage, forKey: memoryCacheKey)

				withAnimation(transaction.animation) {
					phase = .success(Image(platformImage: platformImage))
				}
			} else {
				throw URLError(.cannotDecodeRawData)
			}
		} catch {
			guard !Task.isCancelled else { return }
			withAnimation(transaction.animation) {
				phase = .failure(error)
			}
		}
	}
}

// MARK: - Downsampling Engine

private func downsample(imageData: Data, to pointSize: CGSize, scale: CGFloat) -> PlatformImage? {
	let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
	guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, imageSourceOptions) else { return nil }

	let maxDimensionInPixels = max(pointSize.width, pointSize.height) * scale
	let downsampleOptions = [
		kCGImageSourceCreateThumbnailFromImageAlways: true,
		kCGImageSourceShouldCacheImmediately: true,
		kCGImageSourceCreateThumbnailWithTransform: true,
		kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
	] as CFDictionary

	guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else { return nil }

	#if canImport(UIKit)
	return UIImage(cgImage: downsampledImage)
	#elseif canImport(AppKit)
	return NSImage(cgImage: downsampledImage, size: NSSize(width: pointSize.width, height: pointSize.height))
	#endif
}

#Preview {
	VStack(spacing: 20) {
		Text("Optimized AsyncImage")
			.font(.headline)

		OptimizedAsyncImage(
			url: URL(string: "https://picsum.photos/id/237/2000/2000"),
			targetSize: CGSize(width: 150, height: 150)
		) { phase in
			switch phase {
			case .empty:
				ZStack {
					Color.gray.opacity(0.2)
					ProgressView()
				}
				.frame(width: 150, height: 150)
				.clipShape(RoundedRectangle(cornerRadius: 16))

			case let .success(image):
				image
					.resizable()
					.aspectRatio(contentMode: .fill)
					.frame(width: 150, height: 150)
					.clipShape(RoundedRectangle(cornerRadius: 16))
					.shadow(radius: 4, y: 2)

			case .failure:
				ZStack {
					Color.red.opacity(0.2)
					Image(systemName: "photo.badge.exclamationmark")
						.foregroundColor(.red)
						.font(.largeTitle)
				}
				.frame(width: 150, height: 150)
				.clipShape(RoundedRectangle(cornerRadius: 16))

			@unknown default:
				EmptyView()
			}
		}
	}
	.padding()
}
