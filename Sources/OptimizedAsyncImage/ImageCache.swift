//
//  ImageCache.swift
//  OptimizedAsyncImage
//
//  Created by Daniel Illescas Romero on 8/5/26.
//

import ImageIO
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A thread-safe cache for downloading and downsampling images.
public actor ImageCache {
	public static let shared = ImageCache()

	// 1. Memory Cache
	private let memoryCache: NSCache<NSString, PlatformImage> = {
		let cache = NSCache<NSString, PlatformImage>()
		cache.countLimit = 200
		return cache
	}()

	// 2. Disk Cache
	private let fileManager = FileManager.default
	private var diskCacheDirectory: URL {
		let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
		let directory = urls[0].appendingPathComponent("OptimizedImageCache")

		if !fileManager.fileExists(atPath: directory.path) {
			try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
		}
		return directory
	}

	private func getDiskFileURL(for urlString: String) -> URL {
		let safeName = Data(urlString.utf8).base64EncodedString()
			.replacingOccurrences(of: "/", with: "_")
			.replacingOccurrences(of: "+", with: "-")
		return diskCacheDirectory.appendingPathComponent(safeName)
	}

	public init() {}

	// MARK: Public Operations

	public func getMemoryImage(forKey key: String) -> PlatformImage? {
		memoryCache.object(forKey: key as NSString)
	}

	public func saveToMemory(_ image: PlatformImage, forKey key: String) {
		memoryCache.setObject(image, forKey: key as NSString)
	}

	public func getDiskData(for urlString: String) -> Data? {
		let fileURL = getDiskFileURL(for: urlString)
		return try? Data(contentsOf: fileURL)
	}

	public func saveToDisk(_ data: Data, for urlString: String) {
		let fileURL = getDiskFileURL(for: urlString)
		try? data.write(to: fileURL)
	}

	/// Clears both memory and disk caches.
	public func clearCache() {
		memoryCache.removeAllObjects()
		try? fileManager.removeItem(at: diskCacheDirectory)
	}
}
