---
id: m27-l05
title: Scroll performance and image caching
description: The image grid is where most UIKit apps first drop frames. You reproduce the wrong-image bug that cell reuse causes with asynchronous loads and fix it with a task per cell and an identity check, keep decoded images in an NSCache, decode only the pixels you show by downsampling with ImageIO, share one download between a prefetch and a cell, and model the cache and cancellation logic in plain Swift so you can test it.
module: m27
order: 5
level: advanced
minutes: 75
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m27-l04]
objectives:
  - Explain why reused cells show the wrong image when loads finish out of order, and fix it with cancellation plus an identity check.
  - Load each cell's image in a Task owned by the cell and cancel it in prepareForReuse().
  - Cache decoded images in NSCache with a cost, and explain why its limits and eviction order aren't guarantees.
  - Compute a decoded image's memory cost and downsample with ImageIO (or UIImage's thumbnail API) to the displayed pixel size.
  - Use UICollectionViewDataSourcePrefetching to start loads early and cancel them, sharing one load between a prefetch and a cell.
  - Keep main-thread work per cell small enough to avoid commit hitches.
terms:
  - term: Wrong-image bug
    definition: "A reused cell shows an image meant for a row it displayed earlier, because a slow load started for that row finished after the cell was reconfigured for a new one."
  - term: Identity check
    definition: "Before applying an async result to a cell, comparing the item the result is for with the item the cell currently represents, and dropping the result if they differ."
  - term: NSCache
    definition: "A Foundation key-value store for objects that are expensive to create but can be recreated. It's safe to use from several threads and evicts entries on its own when memory is needed or its limits are exceeded, in no guaranteed order."
  - term: Downsampling
    definition: "Decoding an image directly at the smaller pixel size it's displayed at, instead of decoding it at full size and letting the view scale it. It cuts memory and decode time."
  - term: Prefetching
    definition: "Starting the work for cells that are about to appear, from collectionView(_:prefetchItemsAt:), so the data is ready or in flight when the cell is configured."
  - term: Request coalescing
    definition: "Making several requests for the same resource share one in-flight load, so a prefetch and a cell for the same URL don't download it twice."
mastery:
  - Reproduce the wrong-image bug in a plain-Swift model and show that cancellation plus an identity check fixes it.
  - Write a collection view cell that loads its image in a Task, checks identity before applying it and cancels in prepareForReuse().
  - Write an image loader that checks a cache, coalesces in-flight loads and downsamples.
  - Compute the decoded size of a photo and of its thumbnail, and pick a maximum pixel size for a cell.
  - Write a reference-counted request tracker that only cancels a load nobody needs.
resources: [foundation-nscache, uikit-prefetching, xcode-understanding-hitches, uikit-prepareforreuse, uikit-cell-registration, uikit-diffable-data-sources, xcode-reduce-memory, understanding-hangs]
cards:
  - id: m27-l05-c1
    front: How does the wrong-image bug happen?
    back: "A cell starts loading row 3's image, is reused for row 40, and starts row 40's load. If row 3's load finishes last, it sets its image on the cell now showing row 40. Fix: cancel the old load in prepareForReuse() and, when any load finishes, apply it only if the cell still represents that item."
  - id: m27-l05-c2
    front: Are NSCache's countLimit and totalCostLimit strict?
    back: "No. Apple: they're not strict limits; going over may evict an object instantly, later or never, and the eviction order isn't guaranteed. Treat NSCache as a hint-driven cache, never as storage."
  - id: m27-l05-c3
    front: How much memory does a decoded 4032 × 3024 photo take?
    back: "At 4 bytes per pixel (8-bit RGBA, the common case): 4032 × 3024 × 4 = 48,771,072 bytes, about 46.5 MB, no matter how small the file was or how small it's displayed. Downsample to the displayed pixel size."
  - id: m27-l05-c4
    front: Which ImageIO call downsamples, and with which key options?
    back: "CGImageSourceCreateThumbnailAtIndex with kCGImageSourceCreateThumbnailFromImageAlways, kCGImageSourceThumbnailMaxPixelSize (the larger displayed dimension in pixels) and kCGImageSourceCreateThumbnailWithTransform; create the source with kCGImageSourceShouldCache set to false."
  - id: m27-l05-c5
    front: Can you rely on collectionView(_:prefetchItemsAt:) being called?
    back: "No. Apple: it isn't necessarily called for every cell, and not for cells needed immediately. cellForItemAt must handle data that's ready, in flight, or not requested yet."
---

## The idea in one sentence

A smooth image grid comes from four separate fixes that all aim at the main thread's frame budget: never let a late result land on a reused cell, never decode more pixels than you show, never decode or download the same image twice, and start the work before the cell needs it.

> [!note] About this lesson's code
> UIKit, ImageIO and Foundation blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) on the CI runner, not run. Behavior comes from Apple's reference pages for `NSCache`, `UIImage`, `CGImageSourceCreateThumbnailAtIndex(_:_:_:)` and its option keys, `UICollectionViewDataSourcePrefetching`, `UICollectionView` and `prepareForReuse()`, read in November 2026. The bug, the cache, the memory math and the request tracker are plain Swift, compiled and run with Swift 6.3. `Task`, `await` and actors are Module 29; this lesson uses them the way Module 24 did, for the pattern.

## Where the time goes

Lesson 4's render loop gives the main thread one refresh interval per frame, 8.3 ms at 120 Hz, and while a list scrolls a new cell can appear in any frame. Everything a cell does in `cellForItemAt`, layout and drawing happens inside that budget. The usual offenders in an image grid:

| Work | Where it should happen |
| --- | --- |
| Downloading | Off the main thread, already true of `URLSession` |
| Decoding a JPEG or HEIC into pixels | Off the main thread. Apple's `preparingForDisplay()` page: if the Animation Hitches instrument "indicates that decoding an image takes too long and causes hitches", move "the decoding work to the background" |
| Decoding a full-size photo for a small cell | Nowhere: decode at the displayed size |
| Decoding the same image again on every scroll | Nowhere: cache the decoded result |
| Applying the image to the cell | On the main thread, after checking the cell still wants it |

Module 24 introduced the first defense against reused cells (cancel in `prepareForReuse()` and check identity). This lesson builds the complete loader.

## The wrong-image bug, reproduced

One cell is configured for row 3, scrolls off, and is reused for row 40 before row 3's image arrives. Row 40's image happens to load faster. A plain-Swift model with the loads completing in that order:

```swift
final class Cell {
    let number: Int
    var showing = "placeholder"
    var representedItem: String?

    init(number: Int) {
        self.number = number
    }
}

struct PendingLoad {
    let item: String
    let cell: Cell
    var isCancelled = false
}

func simulate(checkIdentity: Bool) {
    let cell = Cell(number: 1)
    var pending: [PendingLoad] = []

    func configure(_ cell: Cell, for item: String) {
        if checkIdentity {
            for index in pending.indices where pending[index].cell === cell {
                pending[index].isCancelled = true
            }
        }
        cell.representedItem = item
        cell.showing = "placeholder"
        pending.append(PendingLoad(item: item, cell: cell))
    }

    func complete(_ item: String) {
        guard let index = pending.firstIndex(where: { $0.item == item }) else { return }
        let load = pending.remove(at: index)
        if checkIdentity && (load.isCancelled || load.cell.representedItem != item) {
            print("  \(item) finished: discarded")
            return
        }
        load.cell.showing = "\(item).jpg"
        print("  \(item) finished: cell #\(load.cell.number) shows \(load.cell.showing)")
    }

    print(checkIdentity ? "with cancellation and identity check:" : "naive:")
    configure(cell, for: "row3")
    configure(cell, for: "row40")
    complete("row40")
    complete("row3")
    print("  row40's cell ends up showing \(cell.showing)")
}

simulate(checkIdentity: false)
simulate(checkIdentity: true)
```

```output
naive:
  row40 finished: cell #1 shows row40.jpg
  row3 finished: cell #1 shows row3.jpg
  row40's cell ends up showing row3.jpg
with cancellation and identity check:
  row40 finished: cell #1 shows row40.jpg
  row3 finished: discarded
  row40's cell ends up showing row40.jpg
```

In the naive run, the correct image appears and is then **replaced** by the stale one. On a device this looks like images flickering and settling on the wrong row during fast scrolls, worse on slow networks, where loads finish in a less predictable order.

The fixed run uses both defenses. **Cancellation** marks the old load as unwanted when the cell is reconfigured, which in a real app also stops the download and saves bandwidth. The **identity check** compares the item a result is for with the item the cell represents now. You need both: cancellation can arrive too late to stop a load that's already finishing, and the identity check alone would still waste the download.

## A task per cell

The same two defenses in a collection view cell. The cell owns the `Task` that loads its image, so it can cancel it:

```swift ios
import UIKit

protocol ImageLoading: Sendable {
    func image(for url: URL, maxPixelSize: CGFloat) async -> UIImage?
}

final class PhotoCell: UICollectionViewCell {
    private let imageView = UIImageView()
    private var loadTask: Task<Void, Never>?
    private var representedURL: URL?

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .secondarySystemFill
        imageView.frame = contentView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(imageView)
    }

    required init?(coder: NSCoder) {
        fatalError("Built in code")
    }

    func configure(url: URL, loader: any ImageLoading) {
        representedURL = url
        imageView.image = nil
        let maxPixelSize = max(bounds.width, bounds.height) * traitCollection.displayScale

        loadTask = Task { [weak self] in
            let image = await loader.image(for: url, maxPixelSize: maxPixelSize)
            guard let self, !Task.isCancelled, representedURL == url else { return }
            imageView.image = image
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        loadTask = nil
        representedURL = nil
    }
}
```

- **`configure(url:loader:)`** sets everything the cell shows for this item, including the empty placeholder, every time. That's Module 24's rule: content is set in the configuration, not left over from the previous row.
- **The `Task`** is created in a main-actor method, so its body runs on the main actor: when the `await` returns, touching `imageView` is safe. The loading itself happens wherever the loader runs it.
- **`[weak self]`**: the cell can be deallocated while the load is in flight, and the task shouldn't keep it alive.
- **Three checks before applying**: the cell still exists, the task wasn't cancelled, and `representedURL == url`.
- **`prepareForReuse()`** cancels the task and clears the identity. Apple's documentation for it says to reset "attributes of the cell that are not related to content"; cancelling work for the old row belongs there. The image itself is reset by `configure`.
- **`maxPixelSize`** is the cell's larger side in pixels: points times the display scale. The loader decodes the image at that size.

Cancelling a `Task` sets a flag; it doesn't stop code that doesn't check. `URLSession`'s async methods do respond to cancellation of the task that awaits them. Whether cancelling the cell's task cancels the download depends on how the loader is built, as the next sections show.

## Caching: NSCache

Scrolling back up shouldn't download and decode the same images again. `NSCache` is the standard in-memory cache, and its documentation explains what makes it different from a dictionary:

- It "incorporates various auto-eviction policies, which ensure that a cache doesn't use too much of the system's memory."
- "You can add, remove, and query items in the cache from different threads without having to lock the cache yourself."
- It doesn't copy its keys, and both keys and values must be classes (`NSCache<KeyType: AnyObject, ObjectType: AnyObject>`), so a `URL` key is bridged to `NSURL`.

Its limits are softer than they look. `countLimit`: "This is not a strict limit—if the cache goes over the limit, an object in the cache could be evicted instantly, later, or possibly never." `totalCostLimit` says the same, and adds: "The order in which the cache evicts objects is not guaranteed." When you store an image, pass a **cost**; Apple: "Typically, the obvious cost is the size of the value in bytes." For a decoded image, that's its bitmap size.

So `NSCache` is right for "keep what you can, drop what you must", and wrong for anything you can't recompute. If you need a predictable policy, for example least recently used with an exact budget, you write it yourself. The logic is short:

```swift
struct LRUCache {
    let costLimit: Int
    private(set) var totalCost = 0
    private var entries: [String: Int] = [:]
    private var order: [String] = []

    init(costLimit: Int) {
        self.costLimit = costLimit
    }

    mutating func value(for key: String) -> Int? {
        guard let cost = entries[key] else { return nil }
        touch(key)
        return cost
    }

    mutating func insert(_ key: String, cost: Int) {
        if let old = entries[key] {
            totalCost -= old
        }
        entries[key] = cost
        totalCost += cost
        touch(key)
        while totalCost > costLimit, let oldest = order.first {
            order.removeFirst()
            totalCost -= entries.removeValue(forKey: oldest) ?? 0
            print("evicted \(oldest)")
        }
    }

    private mutating func touch(_ key: String) {
        order.removeAll { $0 == key }
        order.append(key)
    }

    var keys: [String] { order }
}

var cache = LRUCache(costLimit: 10)
cache.insert("a", cost: 4)
cache.insert("b", cost: 3)
cache.insert("c", cost: 2)
_ = cache.value(for: "a")
cache.insert("d", cost: 3)
print(cache.keys, cache.totalCost)
cache.insert("e", cost: 9)
print(cache.keys, cache.totalCost)
```

```output
evicted b
["c", "a", "d"] 9
evicted c
evicted a
evicted d
["e"] 9
```

- `order` runs from least to most recently used. Reading `"a"` moves it to the end, so when `"d"` pushes the total to 12, the oldest entry is `"b"`, not `"a"`.
- Inserting `"e"` (cost 9) evicts until the total fits: `"c"`, `"a"` and `"d"` all go.
- The value here is just the cost, to keep the model small; in an app it would be the image. The `removeAll` in `touch` is linear in the number of entries; production LRU caches use a dictionary plus a doubly linked list to make every operation constant time.

## Decode only what you show

A photo's file size says little about its memory cost. Once decoded for display, an image takes width × height × bytes per pixel, and for the common 8-bit RGBA format that's 4 bytes per pixel:

```swift
func decodedBytes(widthPixels: Int, heightPixels: Int, bytesPerPixel: Int = 4) -> Int {
    widthPixels * heightPixels * bytesPerPixel
}

func megabytes(_ bytes: Int) -> String {
    let tenths = (bytes * 10 + 524_288) / 1_048_576
    return "\(tenths / 10).\(tenths % 10) MB"
}

let photo = decodedBytes(widthPixels: 4032, heightPixels: 3024)
let cellSide = 100 * 3
let thumbnail = decodedBytes(widthPixels: cellSide, heightPixels: cellSide * 3024 / 4032)
print(photo, megabytes(photo))
print(thumbnail, megabytes(thumbnail))
print("ratio:", photo / thumbnail)
```

```output
48771072 46.5 MB
270000 0.3 MB
ratio: 180
```

A 12-megapixel camera photo decodes to about 46.5 MB (here 1 MB is 1,048,576 bytes). Shown in a 100-point cell on a 3× screen, it needs at most 300 pixels on its longer side: 300 × 225 pixels, 270,000 bytes, 180 times less. Twenty such photos decoded at full size would be over 900 MB, enough for the system to terminate the app. `UIImageView`'s content mode scales the full bitmap down for display, but the full bitmap still has to exist.

Apple's `preparingThumbnail(of:)` page puts it directly: "when the native image size is much larger than the bounds of the view, decoding the full size image creates unnecessary memory overhead. By creating a thumbnail image at a specified size with this method, you avoid the overhead of decoding the image at its full size."

### Downsampling with ImageIO

ImageIO can decode straight to a smaller size, without ever creating the full bitmap:

```swift ios
import ImageIO
import UIKit

func downsample(_ data: Data, maxPixelSize: CGFloat) -> UIImage? {
    let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
    guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else {
        return nil
    }
    let thumbnailOptions: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
    ]
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
        return nil
    }
    return UIImage(cgImage: cgImage)
}
```

The options, from Apple's ImageIO reference:

- **`kCGImageSourceShouldCache: false`** on the source: "whether to cache the decoded image". You only want the thumbnail, not a cached full decode.
- **`kCGImageSourceCreateThumbnailFromImageAlways: true`**: "the image source creates the thumbnail from the full image, subject to the limit specified by kCGImageSourceThumbnailMaxPixelSize." Without it, ImageIO may return a small thumbnail embedded in the file (many JPEGs carry one), which can be lower resolution than you asked for.
- **`kCGImageSourceThumbnailMaxPixelSize`**: "The maximum width and height of a thumbnail image, specified in pixels." Without it, "the image source creates the thumbnail using the image's full size, which in most cases is not desirable."
- **`kCGImageSourceCreateThumbnailWithTransform: true`** rotates the thumbnail to the photo's orientation; otherwise portrait photos taken with the camera may come out sideways.
- **`kCGImageSourceShouldCacheImmediately: true`** decodes at creation time instead of "only when you render the image", which would be on the main thread during a frame. Apple's reference lists this key for `CGImageSourceCopyPropertiesAtIndex` and `CGImageSourceCreateImageAtIndex`; the widely used downsampling recipe, which Apple presented at WWDC 2018, passes it to the thumbnail function as well.

The function isn't main-actor isolated, and that's intentional: it should run off the main thread. `UIImage` allows that; its documentation says image objects are "safe to create and use from any thread."

> [!tip] UIKit's own thumbnail API
> Since iOS 15, `UIImage` has `preparingThumbnail(of:)`, synchronous, and `byPreparingThumbnail(ofSize:)`, the async form of `prepareThumbnail(of:completionHandler:)`, which "Creates a thumbnail image at the specified size asynchronously on a background thread." They start from a `UIImage`, for example one made with `UIImage(data:)`. Apple's pages call the parameter "The desired size of the thumbnail" without saying whether it's in points or pixels, so check the size of the image you get back before relying on it. ImageIO gives you more control (orientation, caching, embedded thumbnails, explicit pixels); the UIKit methods are less code.

## The loader: cache, coalescing, downsampling

An actor protects the loader's state, the in-flight table, from concurrent access. Every cell and every prefetch call goes through `image(for:maxPixelSize:)`:

```swift ios
import ImageIO
import UIKit

protocol ImageLoading: Sendable {
    func image(for url: URL, maxPixelSize: CGFloat) async -> UIImage?
}

func downsample(_ data: Data, maxPixelSize: CGFloat) -> UIImage? {
    let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
    guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else {
        return nil
    }
    let thumbnailOptions: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
    ]
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
        return nil
    }
    return UIImage(cgImage: cgImage)
}

actor ImageLoader: ImageLoading {
    private let cache = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    init(totalCostLimit: Int) {
        cache.totalCostLimit = totalCostLimit
    }

    func image(for url: URL, maxPixelSize: CGFloat) async -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }
        if let running = inFlight[url] {
            return await running.value
        }

        let task = Task<UIImage?, Never> {
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
            return downsample(data, maxPixelSize: maxPixelSize)
        }
        inFlight[url] = task
        let image = await task.value
        inFlight[url] = nil

        if let image, let cgImage = image.cgImage {
            cache.setObject(image, forKey: url as NSURL, cost: cgImage.bytesPerRow * cgImage.height)
        }
        return image
    }
}

let loader = ImageLoader(totalCostLimit: 50 * 1_048_576)
```

1. **Cache first.** A hit returns immediately.
2. **Coalescing.** If a load for this URL is already running, wait for its result instead of starting another. A prefetch followed by the cell for the same item costs one download.
3. **Otherwise start one** and record it in `inFlight` before the first `await`. Actors are re-entrant: while this call is suspended, another call for the same URL can run, and it must find the entry.
4. **Cache the decoded image** with its bitmap size as the cost, and remove the entry.
5. **`totalCostLimit`** of 50 MB is a budget you choose, not a guarantee, as the `NSCache` section explained.

The download and the decode run in a `Task` started inside the actor, so the decodes run one at a time on the actor. That matches the advice on Apple's `preparingForDisplay()` page: decoding many images "from a concurrent queue can degrade performance by demanding too many system threads. Use a serial queue instead." The price is that a cache hit waits while another image decodes; a larger app would decode on its own serial executor and keep the actor for bookkeeping. The cache key ignores `maxPixelSize`, which is fine while all cells are the same size; with several sizes, put the size in the key.

The shared task is **not** cancelled when one waiting cell is cancelled, because another cell or a prefetch may still want the image. Cancelling it only when nobody is waiting needs a count of interested callers, which is the exercise at the end of the lesson.

## Prefetching

`UICollectionViewDataSourcePrefetching` (iOS 10) tells you which items are likely to appear soon. Apple: "The collection view calls this method as the user scrolls, providing the index paths for cells it's likely to display in the near future," and "The order of the index paths provided represents the priority."

```swift ios
import UIKit

protocol ImageLoading: Sendable {
    func image(for url: URL, maxPixelSize: CGFloat) async -> UIImage?
}

@MainActor
final class PhotoPrefetcher: NSObject, UICollectionViewDataSourcePrefetching {
    private let loader: any ImageLoading
    private let maxPixelSize: CGFloat
    private let urlForItem: (IndexPath) -> URL?
    private var tasks: [URL: Task<Void, Never>] = [:]

    init(loader: any ImageLoading, maxPixelSize: CGFloat, urlForItem: @escaping (IndexPath) -> URL?) {
        self.loader = loader
        self.maxPixelSize = maxPixelSize
        self.urlForItem = urlForItem
    }

    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            guard let url = urlForItem(indexPath), tasks[url] == nil else { continue }
            let loader = loader
            let size = maxPixelSize
            tasks[url] = Task { [weak self] in
                _ = await loader.image(for: url, maxPixelSize: size)
                self?.tasks[url] = nil
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            guard let url = urlForItem(indexPath) else { continue }
            tasks.removeValue(forKey: url)?.cancel()
        }
    }
}
```

You assign it with `collectionView.prefetchDataSource = prefetcher` (a `weak` property, so keep a strong reference elsewhere, usually in the view controller).

- **Prefetching only warms the loader's cache.** The cell still calls the loader in `configure`; if the prefetch already finished, that's a cache hit, and if it's still running, the cell joins it through coalescing.
- **Don't depend on it.** Apple: "The collection view doesn't call this method for cells it requires immediately, so your code must not rely on this method to load data." The cell's own load path must work alone.
- **Key by item, not index path.** Index paths change when items are inserted or deleted (Module 24's diffable data sources); a URL or item ID doesn't.
- **Cancellation** removes the prefetcher's task. With the loader above, that doesn't stop the shared download (see the previous section), which is often acceptable: the image will probably be needed again soon.

Two more facts from `UICollectionView`'s documentation affect how you configure cells. With `isPrefetchingEnabled` (on by default), the collection view also requests **cells** in advance, "spreading the rendering over multiple layout passes", so `cellForItemAt` can run before a cell is visible; Apple suggests updating visual state such as selection in `collectionView(_:willDisplay:forItemAt:)`. And since iOS 15, `cellForItem(at:)` can return a prepared cell that isn't currently visible.

## Common mistakes

> [!error] Setting the image from a completion handler without checking identity
> A reused cell shows another row's image. Store the item the cell represents and compare before applying, and cancel the old load in `prepareForReuse()`.

> [!error] Decoding full-size images for thumbnails
> A 12-megapixel photo is about 46.5 MB decoded, whatever its file size. Downsample to the displayed pixel size; `UIImageView`'s scaling doesn't reduce memory.

> [!error] Decoding on the main thread
> An image that isn't decoded yet gets decoded when it's first rendered, on the main thread, in the middle of a scroll. ImageIO's default, per `kCGImageSourceShouldCacheImmediately`, is to decode "only when you render the image", and `UIImage` offers `preparingForDisplay()` precisely so you can move "the decoding work to the background." Decode ahead of time with that key, `byPreparingThumbnail(ofSize:)` or `prepareForDisplay(completionHandler:)`.

> [!error] Treating NSCache as storage
> Its limits aren't strict and its eviction order isn't guaranteed. Anything you can't recreate belongs on disk or in your model.

> [!error] Keying prefetch work by index path
> After an insert or delete, the index path refers to another item. Key by a stable item ID or URL.

> [!error] Relying on prefetching
> Apple says it isn't called for every cell. The cell's own load path must handle "not requested yet" and "in flight", not just "ready".

> [!error] Using the view's size in points as the pixel size
> `kCGImageSourceThumbnailMaxPixelSize` is in pixels. Multiply by `traitCollection.displayScale`, or thumbnails look soft on Retina screens.

## Exercises

````exercise
id: m27-l05-e1
type: prediction
prompt: "Using the lesson's LRUCache (repeated so it compiles on its own), what does this print?"
code: |
  struct LRUCache {
      let costLimit: Int
      private(set) var totalCost = 0
      private var entries: [String: Int] = [:]
      private var order: [String] = []

      init(costLimit: Int) {
          self.costLimit = costLimit
      }

      mutating func value(for key: String) -> Int? {
          guard let cost = entries[key] else { return nil }
          touch(key)
          return cost
      }

      mutating func insert(_ key: String, cost: Int) {
          if let old = entries[key] {
              totalCost -= old
          }
          entries[key] = cost
          totalCost += cost
          touch(key)
          while totalCost > costLimit, let oldest = order.first {
              order.removeFirst()
              totalCost -= entries.removeValue(forKey: oldest) ?? 0
              print("evicted \(oldest)")
          }
      }

      private mutating func touch(_ key: String) {
          order.removeAll { $0 == key }
          order.append(key)
      }

      var keys: [String] { order }
  }

  var cache = LRUCache(costLimit: 8)
  cache.insert("x", cost: 3)
  cache.insert("y", cost: 3)
  print(cache.value(for: "z") ?? -1)
  cache.insert("x", cost: 5)
  print(cache.keys, cache.totalCost)
  _ = cache.value(for: "y")
  cache.insert("w", cost: 1)
  print(cache.keys, cache.totalCost)
output: |
  -1
  ["y", "x"] 8
  evicted x
  ["y", "w"] 4
hints:
  - "A miss doesn't change the order."
  - "Re-inserting x replaces its old cost and makes it the most recent. Is 8 over a limit of 8?"
  - "Reading y makes it the most recent, so which key is oldest when w arrives?"
solution: |
  ```output
  -1
  ["y", "x"] 8
  evicted x
  ["y", "w"] 4
  ```

  1. After inserting `"x"` and `"y"`, the total is 6 and the order is x, y.
  2. The miss for `"z"` returns `nil`, printed as -1, and doesn't touch the order.
  3. Re-inserting `"x"` with cost 5 subtracts its old cost (6 − 3 = 3), adds the new one (8) and moves `"x"` to the end. The loop evicts only while the total is **greater than** the limit, and 8 isn't, so nothing goes.
  4. Reading `"y"` moves it to the end: the order is now x, y.
  5. Inserting `"w"` makes the total 9, over the limit. The least recently used key is `"x"`, even though it was inserted most recently two steps ago: reads count as use. Evicting it (cost 5) brings the total to 4.
````

````exercise
id: m27-l05-e2
type: solve
prompt: |
  The loader in the lesson never cancels a shared download, because one caller giving up doesn't mean nobody wants the image. Model the fix: a `RequestTracker` that counts how many callers want each URL.

  - `request(_:)` prints `start <url>` the first time a URL is requested and `join <url>` when it's already in flight, and counts the caller.
  - `cancel(_:)` removes one caller. When the last caller leaves, it prints `cancel <url>` and forgets the URL. Cancelling a URL that isn't in flight does nothing.
  - `finish(_:)` prints `deliver <url> to <n>` with the number of callers still waiting, and forgets the URL; if nobody is waiting (it was cancelled), it prints `drop <url>`.

  ```swift
  let tracker = RequestTracker()
  tracker.request("10.jpg")
  tracker.request("11.jpg")
  tracker.request("12.jpg")
  tracker.request("10.jpg")
  tracker.cancel("12.jpg")
  tracker.cancel("10.jpg")
  tracker.finish("10.jpg")
  tracker.finish("12.jpg")
  tracker.cancel("11.jpg")
  tracker.finish("11.jpg")
  ```

  should print:

  ```plaintext
  start 10.jpg
  start 11.jpg
  start 12.jpg
  join 10.jpg
  cancel 12.jpg
  deliver 10.jpg to 1
  drop 12.jpg
  cancel 11.jpg
  drop 11.jpg
  ```
starter: |
  final class RequestTracker {
      // your properties

      func request(_ url: String) {
          // your code
      }

      func cancel(_ url: String) {
          // your code
      }

      func finish(_ url: String) {
          // your code
      }
  }
hints:
  - "A [String: Int] dictionary from URL to number of callers is enough."
  - "removeValue(forKey:) returns the old value, or nil if there was none."
rubric:
  - The first request starts a load; later ones join it.
  - Cancelling only cancels the load when the last caller leaves.
  - Finishing delivers to the remaining callers, or drops the result if none remain.
  - Cancelling an unknown URL does nothing.
solution: |
  ```swift
  final class RequestTracker {
      private var interest: [String: Int] = [:]

      func request(_ url: String) {
          if interest[url] == nil {
              print("start \(url)")
          } else {
              print("join \(url)")
          }
          interest[url, default: 0] += 1
      }

      func cancel(_ url: String) {
          guard let count = interest[url] else { return }
          if count == 1 {
              interest[url] = nil
              print("cancel \(url)")
          } else {
              interest[url] = count - 1
          }
      }

      func finish(_ url: String) {
          if let count = interest.removeValue(forKey: url) {
              print("deliver \(url) to \(count)")
          } else {
              print("drop \(url)")
          }
      }
  }

  let tracker = RequestTracker()
  tracker.request("10.jpg")
  tracker.request("11.jpg")
  tracker.request("12.jpg")
  tracker.request("10.jpg")
  tracker.cancel("12.jpg")
  tracker.cancel("10.jpg")
  tracker.finish("10.jpg")
  tracker.finish("12.jpg")
  tracker.cancel("11.jpg")
  tracker.finish("11.jpg")
  ```

  ```output
  start 10.jpg
  start 11.jpg
  start 12.jpg
  join 10.jpg
  cancel 12.jpg
  deliver 10.jpg to 1
  drop 12.jpg
  cancel 11.jpg
  drop 11.jpg
  ```

  Row 10 was requested twice (a prefetch and then the cell), so cancelling the prefetch leaves the cell waiting and the download continues. Row 12 had one caller, so its download is cancelled, and when a result arrives anyway (cancellation can lose the race with completion) it's dropped. In the real loader, `cancel` would call `cancel()` on the stored `Task` when the count reaches zero, and each caller would wrap its `await` in `withTaskCancellationHandler` to call `cancel` when its own task is cancelled (Module 29).
````

````exercise
id: m27-l05-e3
type: comprehension
prompt: "A grid shows 120 × 120-point thumbnails on a 3× iPhone. What should kCGImageSourceThumbnailMaxPixelSize be?"
choices:
  - text: "360"
    correct: true
    why: "The larger side in points times the display scale: 120 × 3."
  - text: "120"
    correct: false
    why: "That's points. The key is in pixels, so the thumbnail would be a third of the needed resolution and look soft."
  - text: "The photo's original width, so nothing is lost when the user zooms."
    correct: false
    why: "That decodes the full image, which is what downsampling avoids. Load a larger version when the user opens the photo."
  - text: "43,200, the number of pixels in the cell"
    correct: false
    why: "The key is a maximum width and height, not an area."
solution: |
  **360.** Apple defines `kCGImageSourceThumbnailMaxPixelSize` as "The maximum width and height of a thumbnail image, specified in pixels." A 120-point square on a 3× screen covers 360 × 360 pixels, so a thumbnail whose longer side is 360 pixels fills it sharply. With `.scaleAspectFill` and a photo that isn't square, the shorter side ends up below 360 and the image is upscaled slightly; if that matters, compute the size from the aspect ratio so the shorter side reaches 360.
````

````exercise
id: m27-l05-e4
type: find-errors
prompt: "This cell loads avatars. Reviewers report wrong avatars after fast scrolling, high memory with large source photos, and jank. Mark every real problem."
code: |
  final class AvatarCell: UICollectionViewCell {
      let imageView = UIImageView()

      func configure(url: URL) {
          Task {
              let (data, _) = try await URLSession.shared.data(from: url)
              imageView.image = UIImage(data: data)
          }
      }

      override func prepareForReuse() {
          super.prepareForReuse()
          imageView.image = nil
      }
  }
choices:
  - text: "The task isn't stored, so prepareForReuse() can't cancel it."
    correct: true
  - text: "There's no identity check before setting the image, so a late result lands on a reused cell."
    correct: true
  - text: "UIImage(data:) keeps the full-size image, and nothing decodes it before it's rendered on the main thread."
    correct: true
  - text: "Nothing is cached, so scrolling back downloads and decodes every avatar again."
    correct: true
  - text: "URLSession can't be used inside a Task."
    correct: false
    why: "data(from:) is an async method made for exactly this."
  - text: "imageView.image can't be set to nil."
    correct: false
    why: "nil is a valid value; it just shows no image."
rubric:
  - I found the unstored task.
  - I found the missing identity check.
  - I found the full-size main-thread decode.
  - I found the missing cache.
solution: |
  Four problems:

  1. **The task is fire-and-forget.** Store it and cancel it in `prepareForReuse()`.
  2. **No identity check.** Save the URL the cell represents and compare it after the `await`.
  3. **`UIImage(data:)`** creates an image at the photo's full resolution, and nothing here decodes it ahead of time, so the decode happens when it's first rendered, on the main thread. Downsample to the cell's pixel size off the main thread.
  4. **No cache.** Go through a loader with an `NSCache` of decoded thumbnails and coalesced in-flight requests.

  (`try await` inside a plain `Task {}` also means errors are silently dropped; the loader in the lesson returns `nil` on failure so the cell keeps its placeholder.)

  The lesson's `PhotoCell` plus `ImageLoader` address all four: the cell owns and cancels its task and checks `representedURL`, and the loader caches, coalesces and downsamples.
````

````exercise
id: m27-l05-e5
type: explain
prompt: "Your teammate wants to delete the marked lines because \"the identity check already prevents wrong images.\" Explain what the identity check covers, what cancellation adds, and why the lesson's cell has both."
code: |
  override func prepareForReuse() {
      super.prepareForReuse()
      loadTask?.cancel()      // delete?
      loadTask = nil          // delete?
      representedURL = nil
  }
rubric:
  - The identity check prevents a stale result from being displayed.
  - Cancellation stops work nobody needs - network, decoding, CPU and memory - during fast scrolls.
  - Cancellation can race with completion, so it can't replace the check.
  - Mentions that with a shared loader, cancellation needs reference counting to avoid cancelling a load someone else wants.
solution: |
  The **identity check** is about correctness: when a load finishes, the cell compares the URL it was started for with the URL it represents now and drops the result if they differ. On its own it does prevent wrong images.

  **Cancellation** is about cost. During a fast fling, a cell may be reused five times in a second. Without cancellation, all five downloads and decodes run to the end and four results are thrown away: wasted bandwidth, battery, CPU time competing with scrolling, and memory for decoded images nobody shows.

  You need **both** because neither covers the other's case. Cancellation is a request: a load that's already decoding or already returning can still deliver a result after `cancel()`, so the check is the last line of defense. And the check alone doesn't save any work.

  One caveat: with a coalescing loader, a cell's cancellation shouldn't cancel a download a prefetch or another cell still wants. That's what the request tracker exercise models: cancel the shared load only when the last interested caller leaves.
````

## Summary

- Reused cells plus async loads produce the wrong-image bug when loads finish out of order. The cell owns a `Task`, cancels it in `prepareForReuse()`, and checks that it still represents the item before applying a result.
- `NSCache` keeps decoded images with a byte cost and is thread-safe, but its limits are soft and its eviction order isn't guaranteed. Write your own policy (like the LRU model) when you need a predictable one.
- A decoded image costs width × height × 4 bytes in the common format, regardless of file size. Downsample to the displayed size in pixels with `CGImageSourceCreateThumbnailAtIndex` (or `byPreparingThumbnail(ofSize:)`), off the main thread.
- A loader that checks the cache, coalesces in-flight requests and caches the result serves both cells and prefetching with one download per image.
- `UICollectionViewDataSourcePrefetching` starts work early and cancels it, but isn't called for every cell; key prefetch work by item, not index path, and keep the cell's own load path complete.
