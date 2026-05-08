# OptimizedAsyncImage 🖼️⚡️

A high-performance, zero-dependency, drop-in replacement for SwiftUI's `AsyncImage` that prevents memory spikes and scroll lag by physically downsampling images before rendering them. 

Includes a built-in two-tier (memory + disk) caching system.

## The Problem

SwiftUI's native `AsyncImage` is convenient, but it has a massive hidden cost: modifiers like `.resizable()` and `.frame()` only change the *visual display bounds*. Behind the scenes, SwiftUI still downloads and decodes the **entire** full-resolution image into memory. 

If you load twenty 4K images into a scrolling `List` or `ScrollView`—even if you constrain them to 50x50 frames—your app will experience massive memory spikes, severe scroll lag (dropped frames), and potential out-of-memory crashes. Native `AsyncImage` also lacks persistent caching, re-downloading images every time they scroll off-screen.

## The Solution

`OptimizedAsyncImage` solves this by using Apple's `ImageIO` framework to read the image data and generate a lightweight thumbnail of the exact size you need, skipping the expensive process of decoding the full-resolution image.

### Features
* 🚀 **Zero Dependencies:** Pure native Swift. No massive third-party libraries.
* 📉 **Physical Downsampling:** Generates lightweight images on background threads.
* ⚡️ **Two-Tier Caching:** Uses `NSCache` for buttery-smooth scrolling, and the file system (`FileManager`) for persistent offline storage.
* 🤝 **Drop-in Replacement:** Hooks directly into SwiftUI's `AsyncImagePhase`, meaning your existing switch statements work perfectly.
* 📱 **Cross-Platform:** Supports iOS 15+, macOS 12+, tvOS 15+, and watchOS 8+.

---

## Installation

You can add `OptimizedAsyncImage` to an Xcode project by adding it as a package dependency.

1. From the **File** menu, select **Add Package Dependencies...**
2. Enter the repository URL for this package.
3. Select the version requirements and choose your target.

---

## Usage

Using `OptimizedAsyncImage` is nearly identical to using SwiftUI's `AsyncImage`. The only difference is that you **must** provide a `targetSize`. This tells the engine exactly how small to shrink the image before decoding it.

```swift
import SwiftUI
import OptimizedAsyncImage

struct ProfileThumbnailView: View {
    let imageURL: URL?
    
    var body: some View {
        OptimizedAsyncImage(
            url: imageURL, 
            targetSize: CGSize(width: 48, height: 48) // 👈 The physical size to decode
        ) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: 48, height: 48)
                
            case let .success(image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                
            case .failure:
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .resizable()
                    .frame(width: 48, height: 48)
                    .foregroundColor(.red)
                
            @unknown default:
                EmptyView()
            }
        }
    }
}
```
