import UIKit
import Foundation

final class ImageCache {
    nonisolated(unsafe) static let shared = NSCache<NSString, UIImage>()

    private init() {}
}

func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
    // 1. Check cache first
    if let cachedImage = ImageCache.shared.object(forKey: url.absoluteString as NSString) {
        completion(cachedImage)
        return
    }

    // 2. Fetch image from network
    URLSession.shared.dataTask(with: url) { data, _, _ in
        guard let data = data, let image = UIImage(data: data) else {
            completion(nil)
            return
        }

        // 3. Save to cache
        ImageCache.shared.setObject(image, forKey: url.absoluteString as NSString)

        DispatchQueue.main.async {
            completion(image)
        }
    }.resume()
}

final class SmartImageCache {
    nonisolated(unsafe) static let shared = SmartImageCache()
    private let imageCache = NSCache<NSString, UIImage>()

    private init() {}

    func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        // Step 1: Try in-memory cache
        if let cached = imageCache.object(forKey: url.absoluteString as NSString) {
            completion(cached)
            return
        }

        // Step 2: Check URLCache for cached response
        if let cachedResponse = URLCache.shared.cachedResponse(for: URLRequest(url: url)),
           let image = UIImage(data: cachedResponse.data) {
            imageCache.setObject(image, forKey: url.absoluteString as NSString)
            completion(image)
            return
        }

        // Step 3: Download and cache both
        URLSession.shared.dataTask(with: url) { data, response, _ in
            guard
                let data = data,
                let response = response,
                let image = UIImage(data: data)
            else {
                completion(nil)
                return
            }

            let cachedData = CachedURLResponse(response: response, data: data)
            URLCache.shared.storeCachedResponse(cachedData, for: URLRequest(url: url))
            self.imageCache.setObject(image, forKey: url.absoluteString as NSString)

            DispatchQueue.main.async {
                completion(image)
            }
        }.resume()
    }
}




// Configure a custom shared cache
let urlCache = URLCache(
    memoryCapacity: 50 * 1024 * 1024, // 50 MB memory
    diskCapacity: 200 * 1024 * 1024,  // 200 MB disk
    directory: nil                    // Use default cache directory
)

URLCache.shared = urlCache

func usingURLSession() {
    let url = URL(string: "https://api.example.com/profile")!
    let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let data = data, let response = response {
            print("✅ Response size: \(data.count) bytes")
        }
    }
    task.resume()
}
