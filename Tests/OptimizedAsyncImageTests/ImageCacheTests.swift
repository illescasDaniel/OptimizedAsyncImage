import Testing
import Foundation
@testable import OptimizedAsyncImage

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@Suite("Image Cache Tests")
struct ImageCacheTests {

	// MARK: - Helpers

	/// Creates a tiny 1x1 platform-specific dummy image for testing memory.
	private func createDummyImage() -> PlatformImage {
		#if canImport(UIKit)
		let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
		UIGraphicsBeginImageContext(rect.size)
		let context = UIGraphicsGetCurrentContext()!
		context.setFillColor(UIColor.red.cgColor)
		context.fill(rect)
		let image = UIGraphicsGetImageFromCurrentImageContext()!
		UIGraphicsEndImageContext()
		return image
		#elseif canImport(AppKit)
		let rect = NSRect(x: 0, y: 0, width: 1, height: 1)
		let image = NSImage(size: rect.size)
		image.lockFocus()
		NSColor.red.drawSwatch(in: rect)
		image.unlockFocus()
		return image
		#endif
	}

	/// Creates dummy text data for testing disk storage.
	private func createDummyData() -> Data {
		Data("dummy_image_data".utf8)
	}

	// MARK: - Tests

	@Test("Memory Cache saves and retrieves images successfully")
	func testMemoryCache() async {
		let cache = ImageCache.shared
		await cache.clearCache() // Reset state

		let dummyImage = createDummyImage()
		let testKey = "test-memory-key"

		// Ensure it's empty initially
		let initialResult = await cache.getMemoryImage(forKey: testKey)
		#expect(initialResult == nil, "Memory cache should be empty initially.")

		// Save and retrieve
		await cache.saveToMemory(dummyImage, forKey: testKey)
		let fetchedResult = await cache.getMemoryImage(forKey: testKey)

		#expect(fetchedResult != nil, "Memory cache should return the saved image.")
	}

	@Test("Disk Cache saves and retrieves raw data successfully")
	func testDiskCache() async {
		let cache = ImageCache.shared
		await cache.clearCache()

		let dummyData = createDummyData()
		let testURLString = "https://example.com/test-image.jpg"

		// Ensure it's empty initially
		let initialResult = await cache.getDiskData(for: testURLString)
		#expect(initialResult == nil, "Disk cache should be empty initially.")

		// Save and retrieve
		await cache.saveToDisk(dummyData, for: testURLString)
		let fetchedResult = await cache.getDiskData(for: testURLString)

		#expect(fetchedResult != nil, "Disk cache should return data.")
		#expect(fetchedResult == dummyData, "Fetched data should match the saved dummy data.")
	}

	@Test("Clear Cache successfully purges memory and disk storage")
	func testClearCache() async {
		let cache = ImageCache.shared
		await cache.clearCache()

		let dummyImage = createDummyImage()
		let dummyData = createDummyData()
		let testMemoryKey = "test-clear-memory-key"
		let testDiskURLString = "https://example.com/test-clear-disk.png"

		// Populate caches
		await cache.saveToMemory(dummyImage, forKey: testMemoryKey)
		await cache.saveToDisk(dummyData, for: testDiskURLString)

		// Verify population
		let memBefore = await cache.getMemoryImage(forKey: testMemoryKey)
		let diskBefore = await cache.getDiskData(for: testDiskURLString)
		#expect(memBefore != nil)
		#expect(diskBefore != nil)

		// Execute clear
		await cache.clearCache()

		// Verify purge
		let memAfter = await cache.getMemoryImage(forKey: testMemoryKey)
		let diskAfter = await cache.getDiskData(for: testDiskURLString)

		#expect(memAfter == nil, "Memory cache should be nil after clearing.")
		#expect(diskAfter == nil, "Disk cache should be nil after clearing.")
	}

	@Test("Disk Cache handles invalid paths gracefully")
	func testDiskCacheInvalidPath() async {
		let cache = ImageCache.shared
		await cache.clearCache()

		// Request an item that was never saved
		let nonExistentURLString = "https://example.com/does-not-exist.jpg"
		let result = await cache.getDiskData(for: nonExistentURLString)

		#expect(result == nil, "Disk cache should safely return nil for missing files.")
	}
}
