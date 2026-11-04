---
id: m45-l03
title: Photos, camera and AVFoundation
description: "Media features are mostly about asking for the least access and owning the right resources. You pick photos with PhotosPicker without any permission, load them safely and downsize them, build a basic camera with AVCaptureSession off the main thread, choose an audio session category that matches what your sound is for, play video with AVPlayer and VideoPlayer, and decide what to do when a phone call interrupts playback."
module: m45
order: 3
level: advanced
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m45-l02, m40-l04]
objectives:
  - Load images from PhotosPicker with loadTransferable(type:) and avoid stale results when the selection changes.
  - Decide when the app needs Photos library authorization, camera or microphone permission, and which purpose string.
  - Configure and run an AVCaptureSession with a photo output, off the main thread, and capture one photo.
  - Choose an audio session category (ambient, soloAmbient, playback, playAndRecord) and know when the audio background mode is needed.
  - Play media with AVPlayer and SwiftUI's VideoPlayer, and activate the audio session when playback starts.
  - Model what happens to playback across an interruption.
terms:
  - term: PhotosPicker
    definition: "SwiftUI's photo picker (iOS 16, in PhotosUI). It runs out of process, so picking needs no Photos permission. Selections are PhotosPickerItem placeholders loaded with loadTransferable(type:)."
  - term: AVCaptureSession
    definition: "AVFoundation's object that connects capture inputs (cameras, microphones) to outputs (photo, movie, video data) and manages exclusive access to the capture hardware. startRunning() blocks until the session runs."
  - term: AVCapturePhotoOutput
    definition: "A capture output for still photos. capturePhoto(with:delegate:) takes a fresh AVCapturePhotoSettings for each shot and reports the result to an AVCapturePhotoCaptureDelegate."
  - term: Audio session category
    definition: "AVAudioSession's description of what your audio is for. It decides whether the Silent switch mutes you, whether you mix with other apps' audio, and whether you can record."
  - term: AVPlayer
    definition: "AVFoundation's playback controller for one item at a time, local or streamed. VideoPlayer (AVKit, iOS 14) shows it in SwiftUI with the system's playback controls."
  - term: Interruption
    definition: "The system deactivating your audio session for a higher-priority sound, like a phone call. AVPlayer pauses on its own; resuming afterwards is the app's decision."
mastery:
  - Write a PhotosPicker screen that loads the selected image with task(id:), handles nil and errors, and downsizes large photos.
  - Say which Info.plist key a media feature needs, or why it needs none.
  - Write a camera service that checks authorization, configures inputs and outputs, starts off the main thread, and captures a photo through a continuation.
  - Choose the audio session category and options for a feature and say what the Silent switch and other apps' audio will do.
  - Trace a player's state through play, pause and interruptions with and without shouldResume.
  - Compute a thumbnail size that keeps the aspect ratio and never upscales.
resources: [photosui-phpickerviewcontroller, requesting-protected-resources, swiftui-task-id, swift-checkedcontinuation, swift-actor, app-review-guidelines]
cards:
  - id: m45-l03-c1
    front: Does PhotosPicker need Photos library permission?
    back: "No. Like PHPickerViewController, it runs in a separate process and is private by default, so the person doesn't authorize the app. Full PhotoKit access needs NSPhotoLibraryUsageDescription; saving only needs NSPhotoLibraryAddUsageDescription."
  - id: m45-l03-c2
    front: Why start an AVCaptureSession off the main thread?
    back: "startRunning() is synchronous and blocks until the session starts or fails. On the main thread that freezes the UI. Keep the session inside an actor or a dedicated queue."
  - id: m45-l03-c3
    front: ambient, soloAmbient or playback?
    back: "ambient: sound isn't essential, mixes with other apps, silenced by the Silent switch and lock. soloAmbient: the default, silenced the same way but stops other audio. playback: sound is central, plays with the switch on silent, and continues in the background with the audio background mode."
  - id: m45-l03-c4
    front: When should you activate the audio session?
    back: "After setting the category, and Apple recommends deferring setActive(true) until playback actually begins, so you don't interrupt other apps' audio before you play anything."
  - id: m45-l03-c5
    front: What happens to an AVPlayer when a phone call comes in?
    back: "The system interrupts the audio session and AVPlayer pauses automatically. When the interruption ends, the app decides whether to resume; with the classic notification, resume only if the options include shouldResume and it was playing before."
---

## The idea in one sentence

Media frameworks give you **powerful access you should take as little of as possible**: the photo picker instead of the library, the camera only while the camera screen is open, and an audio session that says honestly whether your sound matters.

> [!note] Sources and what was checked
> From Apple's documentation, read in November 2026: `PhotosPicker`, `PhotosPickerItem.loadTransferable(type:)`, "Delivering an enhanced privacy experience in your photos app", "Requesting authorization to capture and save media", "Setting up a capture session", `AVCaptureSession.startRunning()`, `AVCapturePhotoOutput.capturePhoto(with:delegate:)`, `AVAudioSession` and its categories, "Configuring your app for media playback", "Handling audio interruptions", `AVAudioSession.interruptionNotification`, `AVPlayer`, AVKit's `VideoPlayer`, and `UIImage.preparingThumbnail(of:)`; plus App Review Guidelines 2.5.14 and 5.1.1. The PhotosUI, AVFoundation, AVKit and SwiftUI blocks are type-checked against the iOS SDK, not run, and no camera code ran on a device. The audio plan, player state and thumbnail models are plain Swift, compiled and run with Swift 6.3.

## Picking photos

Module 40 compared the three pickers and wrapped `PHPickerViewController`. In a SwiftUI screen that only needs a picture, `PhotosPicker` needs no wrapper at all, and, importantly, **no permission**. Apple's privacy article explains why: the picker's "user interface matches that of the Photos app," and "because the system manages its life cycle in a separate process, it's private by default. The user doesn't need to explicitly authorize your app to select photos." Your app only ever sees what the person picked.

Pantry lets people attach a photo of a paper receipt to an order:

```swift ios
import PhotosUI
import SwiftUI
import UIKit

struct ReceiptAttachmentView: View {
    @State private var selection: PhotosPickerItem?
    @State private var thumbnail: UIImage?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            PhotosPicker(selection: $selection, matching: .images) {
                Label("Attach Receipt", systemImage: "doc.text.image")
            }
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
            }
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
        .task(id: selection) {
            await load(selection)
        }
    }

    private func load(_ item: PhotosPickerItem?) async {
        errorMessage = nil
        guard let item else {
            thumbnail = nil
            return
        }
        do {
            let data = try await item.loadTransferable(type: Data.self)
            guard !Task.isCancelled else { return }          // a newer selection replaced this one
            guard let data, let image = UIImage(data: data) else {
                errorMessage = "That file isn't an image Pantry can read."
                return
            }
            thumbnail = image.preparingThumbnail(of: CGSize(width: 1024, height: 768)) ?? image
        } catch {
            errorMessage = "The photo couldn't be loaded. Check your connection and try again."
        }
    }
}
```

- **`loadTransferable(type:)` is async and can fail.** The selection is a placeholder; the data may still be in iCloud. Apple: "A failure can occur when the system attempts to retrieve the data. For example, if the picker tries to download data from iCloud Photos without a network connection." It returns `nil` when the item can't be represented as the requested type.
- **`.task(id: selection)`** cancels the previous load when the selection changes and starts a new one, so a slow first photo can't overwrite a fast second one. Apple's own example compares the item with the current selection after loading for the same reason; the `Task.isCancelled` check here does that job. (Module 36 introduced `task(id:)`.)
- **`Data`, then `UIImage`.** Apple notes that SwiftUI's `Image` "supports only PNG and JPEG file types through its `Transferable` conformance." Loading `Data` and decoding with `UIImage(data:)` handles HEIC, the iPhone camera's usual format.
- **Downsize before keeping it.** A 12-megapixel photo decodes to about 48 MB in memory (4 bytes per pixel). `preparingThumbnail(of:)` avoids "the overhead of decoding the image at its full size." The exact size to request comes from a calculation like the one in the solve exercise. Upload the original `Data` if the server needs full resolution; keep only the thumbnail in memory.

For several photos, use the initializer with `selection: Binding<[PhotosPickerItem]>` and `maxSelectionCount:`. Filters combine: `matching: .any(of: [.images, .not(.screenshots)])` is Apple's example.

### When you do need permission

| What the app does | What it needs |
| --- | --- |
| Lets the person pick photos | Nothing (`PhotosPicker`, `PHPickerViewController`) |
| Saves a photo to the library | `NSPhotoLibraryAddUsageDescription` (add-only access) |
| Browses or edits the library itself (PhotoKit) | `NSPhotoLibraryUsageDescription`, and handle limited access |
| Takes photos or video | `NSCameraUsageDescription` |
| Records sound | `NSMicrophoneUsageDescription` |

Without the key, Apple is blunt: "Attempting to access the Photos library without a valid usage description causes your app to crash," and for capture devices "the system terminates your app." Guideline 5.1.1(iii) asks for the first row whenever it fits: "Where possible, use the out-of-process picker or a share sheet rather than requesting full access to protected resources like Photos or Contacts." And 5.1.1(iv) uses media as its example of over-asking: an app that posts photos "must not also require microphone access before allowing the user to upload photos."

Full-library access also has a partial state: since iOS 14, the person can grant **limited** access to selected photos. Apple's article says this "affects all apps that use PhotoKit," so test that path if you use PhotoKit directly.

## A basic camera with AVCaptureSession

Module 40 used `UIImagePickerController` for the camera: a complete system UI, little control. For a custom capture screen (Pantry wants a receipt-shaped frame and a big shutter button) you build on `AVCaptureSession`. "Setting up a capture session" describes the pieces: an input from a device, an output for the media you want, `beginConfiguration()` and `commitConfiguration()` around changes, and `startRunning()`.

That last call shapes the design. `startRunning()`: "This method is synchronous and blocks until the session starts running or it fails." So the session lives in an **actor**, whose methods run off the main thread, and the UI awaits it:

```swift ios
import AVFoundation

enum CameraError: Error {
    case notAuthorized
    case noCamera
    case cannotAddInput
    case cannotAddOutput
    case noPhotoData
}

actor CameraService {
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var isConfigured = false
    private var captureInProgress: PhotoCaptureDelegate?

    /// Checks permission, configures once, then starts the session on the actor (not the main thread).
    func start() async throws {
        guard await Self.isAuthorized() else { throw CameraError.notAuthorized }
        if !isConfigured {
            try configure()
        }
        session.startRunning()
    }

    func stop() {
        session.stopRunning()
    }

    func capturePhoto() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let delegate = PhotoCaptureDelegate(continuation: continuation)
            captureInProgress = delegate
            photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
        }
    }

    private func configure() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.noCamera
        }
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else { throw CameraError.cannotAddInput }
        session.addInput(input)

        guard session.canAddOutput(photoOutput) else { throw CameraError.cannotAddOutput }
        session.sessionPreset = .photo
        session.addOutput(photoOutput)
        isConfigured = true
    }

    static func isAuthorized() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }
}

/// Receives one capture's result and resumes the caller exactly once.
final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let continuation: CheckedContinuation<Data, any Error>

    init(continuation: CheckedContinuation<Data, any Error>) {
        self.continuation = continuation
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        if let error {
            continuation.resume(throwing: error)
        } else if let data = photo.fileDataRepresentation() {
            continuation.resume(returning: data)
        } else {
            continuation.resume(throwing: CameraError.noPhotoData)
        }
    }
}
```

- **Authorization first.** This is the flow from "Requesting authorization to capture and save media" (and Module 21): check `authorizationStatus(for: .video)`, and only when it's `.notDetermined`, call `requestAccess(for:)`, "only at a time that's appropriate for your app," such as when the person opens the scanner.
- **Configuration in a batch.** Apple: "Call `beginConfiguration()` before changing a session's inputs or outputs, and call `commitConfiguration()` after making changes." The `defer` commits on every path, including a throw.
- **`canAddInput` and `canAddOutput`** can say no (another configuration conflicts, or the device lacks the camera). The simulator has no camera at all, which `AVCaptureDevice.default` reports as `nil`.
- **Fresh settings per shot.** `capturePhoto(with:delegate:)`: "It is illegal to reuse a `AVCapturePhotoSettings` instance for multiple captures," and doing so throws an exception. A new `AVCapturePhotoSettings()` per call avoids it.
- **The delegate and the continuation.** The result arrives in a delegate callback on a queue of AVFoundation's choosing, so the delegate wraps a checked continuation (Module 29) and resumes it once on every path. The actor keeps a reference to the delegate while the capture runs. A real camera screen would also prevent a second tap while a capture is in progress.
- **The preview** (a live viewfinder) is an `AVCaptureVideoPreviewLayer` whose `session` is this session, hosted in a `UIView` subclass as Apple's article shows, and wrapped for SwiftUI with Module 40's representable. Sharing the session between the actor and the main-thread layer takes more care than fits here; Apple's AVCam sample shows a complete version.

Guideline 2.5.14 also applies to anything you record: "Apps must request explicit user consent and provide a clear visual and/or audible indication when recording, logging, or otherwise making a record of user activity. This includes any use of the device camera, microphone." The system shows its own camera indicator; your UI should make it obvious too.

## Audio sessions

Every app has an audio session, and its **category** tells the system what your sound is for. The default behavior, from "Configuring your app for media playback": "Audio playback in your app silences other background audio," "Ring/Silent switch set to silent mode in iOS silences app audio," and "Locked device in iOS silences app audio." The categories you'll use most, from their reference pages:

| Category | For | Silent switch | Other apps' audio |
| --- | --- | --- | --- |
| `.ambient` | Sound that isn't essential ("your app also works with the sound turned off") | Silences it | Mixes |
| `.soloAmbient` | The default | Silences it | Interrupts it (nonmixable) |
| `.playback` | Sound "central to the successful use of your app" | Keeps playing | Interrupts it unless you add `.mixWithOthers` |
| `.playAndRecord` | Recording and playback, like voice chat | Keeps playing | Interrupts it unless you add `.mixWithOthers` |

Playing in the background needs one more thing for `.playback` (and `.playAndRecord`): "add the audio value to the `UIBackgroundModes` key," which Xcode's Background Modes capability labels "Audio, AirPlay, and Picture in Picture." Recording needs microphone permission ("The user must grant permission for audio recording"), requested with `AVAudioApplication.requestRecordPermission()` in iOS 17.

Pantry's audio features, through the same rules:

```swift
struct AudioNeed {
    let feature: String
    let soundIsCentral: Bool       // the feature is pointless without sound
    let records: Bool              // uses the microphone
    let keepsPlayingInBackground: Bool
}

struct AudioPlan {
    let category: String           // AVAudioSession.Category
    let silencedBySilentMode: Bool
    let needsAudioBackgroundMode: Bool
    let needsMicrophonePermission: Bool
}

func audioPlan(for need: AudioNeed) -> AudioPlan {
    if need.records {
        return AudioPlan(category: "playAndRecord", silencedBySilentMode: false,
                         needsAudioBackgroundMode: need.keepsPlayingInBackground,
                         needsMicrophonePermission: true)
    }
    if need.soundIsCentral {
        return AudioPlan(category: "playback", silencedBySilentMode: false,
                         needsAudioBackgroundMode: need.keepsPlayingInBackground,
                         needsMicrophonePermission: false)
    }
    return AudioPlan(category: "ambient", silencedBySilentMode: true,
                     needsAudioBackgroundMode: false, needsMicrophonePermission: false)
}

let features = [
    AudioNeed(feature: "Recipe videos", soundIsCentral: true, records: false, keepsPlayingInBackground: false),
    AudioNeed(feature: "Cooking podcast", soundIsCentral: true, records: false, keepsPlayingInBackground: true),
    AudioNeed(feature: "Add-to-cart sound", soundIsCentral: false, records: false, keepsPlayingInBackground: false),
    AudioNeed(feature: "Voice shopping list", soundIsCentral: true, records: true, keepsPlayingInBackground: false),
]

for need in features {
    let plan = audioPlan(for: need)
    var notes: [String] = []
    if plan.silencedBySilentMode { notes.append("silent switch mutes it") }
    if plan.needsAudioBackgroundMode { notes.append("audio background mode") }
    if plan.needsMicrophonePermission { notes.append("NSMicrophoneUsageDescription") }
    print("\(need.feature): .\(plan.category)" + (notes.isEmpty ? "" : " (" + notes.joined(separator: ", ") + ")"))
}
```

```output
Recipe videos: .playback
Cooking podcast: .playback (audio background mode)
Add-to-cart sound: .ambient (silent switch mutes it)
Voice shopping list: .playAndRecord (NSMicrophoneUsageDescription)
```

- **The add-to-cart sound is `.ambient`.** Someone listening to music while shopping keeps their music; someone with the switch on silent hears nothing. Using `.playback` for a UI sound would stop their music on every tap.
- **Only the podcast gets the background mode.** Guideline 2.5.4 limits background services to "their intended purposes"; a recipe video doesn't need to keep playing in the background.
- One app can use different categories at different times: set the category when the feature starts.

## Playing video

`AVPlayer` plays one item; AVKit's `VideoPlayer` (iOS 14) shows it in SwiftUI with the standard controls. Apple's `VideoPlayer` example creates the player in `.task` "to ensure SwiftUI creates it only once when it first presents the view." Pantry's recipe video:

```swift ios
import AVFoundation
import AVKit
import SwiftUI

struct RecipeVideoView: View {
    let videoURL: URL
    @State private var player: AVPlayer?

    var body: some View {
        VStack {
            if let player {
                VideoPlayer(player: player)
                    .frame(height: 240)
                Button("Play") {
                    play(player)
                }
            } else {
                ProgressView()
            }
        }
        .task {
            configureAudioSession()
            player = AVPlayer(url: videoURL)
        }
        .onDisappear {
            player?.pause()
        }
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        } catch {
            print("Audio session category failed: \(error)")
        }
    }

    private func play(_ player: AVPlayer) {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session activation failed: \(error)")
        }
        player.play()
    }
}
```

- **Category early, activation late.** Apple's playback article sets `.playback` with mode `.moviePlayback`, then: "You can activate the audio session at any time after setting its category, but it's recommended to defer this call until your app begins audio playback. Deferring the call ensures that you don't prematurely interrupt any other background audio." So the screen sets the category when it appears and activates on Play.
- **`.onDisappear` pauses.** Leaving the screen shouldn't leave a recipe talking in the background.
- **`AVPlayer` is a main-actor class** in the current SDK, which matches how views use it.

### Interruptions

A phone call or an alarm interrupts your audio session. "Handling audio interruptions": "`AVPlayer` monitors your app's audio session and automatically pauses playback in response to interruption events." When the interruption ends, whether to resume is up to the app. The classic API is `AVAudioSession.interruptionNotification`, whose "ended" case may carry the `shouldResume` option. (In the iOS 27 SDK, Apple deprecates that type and option in favor of life-cycle notifications, `didBecomeActiveNotification`, `didBecomeInactiveNotification` and `resumptionRecommendationNotification`; the code in this course targets iOS 17 and doesn't use either.)

The rule, as a state machine Pantry's player model follows:

```swift
enum PlayerState {
    case paused, playing, interrupted(wasPlaying: Bool)
}

enum PlayerEvent {
    case tapPlay, tapPause
    case interruptionBegan
    case interruptionEnded(shouldResume: Bool)
}

/// What a video player should do around a phone call. AVPlayer pauses itself when the
/// interruption begins; resuming afterwards is the app's decision.
func next(_ state: PlayerState, _ event: PlayerEvent) -> PlayerState {
    switch (state, event) {
    case (_, .tapPlay):
        return .playing
    case (_, .tapPause):
        return .paused
    case (.playing, .interruptionBegan):
        return .interrupted(wasPlaying: true)
    case (.paused, .interruptionBegan):
        return .interrupted(wasPlaying: false)
    case (.interrupted(let wasPlaying), .interruptionEnded(let shouldResume)):
        return wasPlaying && shouldResume ? .playing : .paused
    default:
        return state
    }
}

var state = PlayerState.paused
let events: [PlayerEvent] = [
    .tapPlay, .interruptionBegan, .interruptionEnded(shouldResume: true),
    .interruptionBegan, .interruptionEnded(shouldResume: false),
    .tapPlay, .tapPause, .interruptionBegan, .interruptionEnded(shouldResume: true),
]
for event in events {
    state = next(state, event)
    print(event, "→", state)
}
```

```output
tapPlay → playing
interruptionBegan → interrupted(wasPlaying: true)
interruptionEnded(shouldResume: true) → playing
interruptionBegan → interrupted(wasPlaying: true)
interruptionEnded(shouldResume: false) → paused
tapPlay → playing
tapPause → paused
interruptionBegan → interrupted(wasPlaying: false)
interruptionEnded(shouldResume: true) → paused
```

- **Resume needs both**: the system's recommendation and the fact that the person was playing. A video the person had paused stays paused after the call, even when the system says resuming is fine.
- **`shouldResume: false`** happens, for example, when another app started playing during the interruption. Starting over it would be rude.
- **Remembering `wasPlaying`** is the part that's easy to forget: the state before the interruption is the information the decision needs.

## Common mistakes

> [!error] Requesting Photos access to let someone pick a picture
> `PhotosPicker` needs no permission. Asking for library access you don't need costs trust, and guideline 5.1.1(iii) asks for the out-of-process picker where possible.

> [!error] Keeping full-size images in memory
> A grid of 12-megapixel photos decoded at full size exhausts memory. Downsize with `preparingThumbnail(of:)` (or ImageIO) and keep the original only as data, if at all.

> [!error] startRunning() on the main thread
> It blocks until the session runs. Call it from an actor or a dedicated queue.

> [!error] Reusing AVCapturePhotoSettings
> Reusing an instance for another capture throws an exception. Create new settings for each shot.

> [!error] .playback for UI sounds
> It stops the person's music and ignores the Silent switch. UI feedback sounds belong in `.ambient`.

> [!error] Resuming after every interruption
> Resume only if the person was playing and the system suggests it.

## Exercises

````exercise
id: m45-l03-e1
type: prediction
prompt: "The player model starts while playing. What does it print?"
code: |
  enum PlayerState {
      case paused, playing, interrupted(wasPlaying: Bool)
  }

  enum PlayerEvent {
      case tapPlay, tapPause
      case interruptionBegan
      case interruptionEnded(shouldResume: Bool)
  }

  func next(_ state: PlayerState, _ event: PlayerEvent) -> PlayerState {
      switch (state, event) {
      case (_, .tapPlay):
          return .playing
      case (_, .tapPause):
          return .paused
      case (.playing, .interruptionBegan):
          return .interrupted(wasPlaying: true)
      case (.paused, .interruptionBegan):
          return .interrupted(wasPlaying: false)
      case (.interrupted(let wasPlaying), .interruptionEnded(let shouldResume)):
          return wasPlaying && shouldResume ? .playing : .paused
      default:
          return state
      }
  }

  var state = PlayerState.playing
  for event: PlayerEvent in [.interruptionEnded(shouldResume: true), .interruptionBegan,
                             .interruptionBegan, .tapPause, .interruptionEnded(shouldResume: true)] {
      state = next(state, event)
      print(state)
  }
output: |
  playing
  interrupted(wasPlaying: true)
  interrupted(wasPlaying: true)
  paused
  paused
hints:
  - "An ended event while playing doesn't match any specific case."
  - "A second began while already interrupted also falls to default."
solution: |
  ```output
  playing
  interrupted(wasPlaying: true)
  interrupted(wasPlaying: true)
  paused
  paused
  ```

  - `.interruptionEnded` while `.playing`: no case matches `(.playing, .interruptionEnded)`, so `default` keeps `playing`.
  - `.interruptionBegan` from `.playing` records `wasPlaying: true`.
  - A second `.interruptionBegan` while interrupted falls to `default`, so the remembered `true` survives. Overwriting it with `false` would lose the reason to resume.
  - `.tapPause` wins from any state, and the final ended event comes while `.paused`, which falls to `default`.
````

````exercise
id: m45-l03-e2
type: comprehension
prompt: "Pantry's add-to-cart 'pop' sound currently uses the .playback category. People complain that their music stops whenever they add an item. What's the fix?"
choices:
  - text: "Use .ambient for the sound, so it mixes with other audio and respects the Silent switch."
    correct: true
    why: "Apple: .ambient is for sound playback that's nonprimary, mixes with other apps' audio, and is silenced by the Silent switch and the lock."
  - text: "Keep .playback and call setActive(false) after each sound."
    correct: false
    why: "Activating a nonmixable session already interrupted the music. Deactivating afterwards doesn't restart it."
  - text: "Use .soloAmbient, the default."
    correct: false
    why: "soloAmbient is also nonmixable; it interrupts other audio the same way."
  - text: "Add the audio background mode."
    correct: false
    why: "That's for continuing playback in the background, unrelated to interrupting other apps."
solution: |
  The category says what the sound is for. A UI sound isn't central: Pantry works fine without it, so `.ambient` fits. It "mixes" with other apps' audio, and the Silent switch and screen lock silence it, which is what people expect from interface sounds.
````

````exercise
id: m45-l03-e3
type: find-errors
prompt: "Mark every real problem in this camera screen model."
code: |
  @MainActor
  final class ScannerModel {
      let session = AVCaptureSession()
      let output = AVCapturePhotoOutput()
      let settings = AVCapturePhotoSettings()

      func open() {
          let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)!
          let input = try! AVCaptureDeviceInput(device: camera)
          session.addInput(input)
          session.addOutput(output)
          session.startRunning()
      }

      func shoot(delegate: AVCapturePhotoCaptureDelegate) {
          output.capturePhoto(with: settings, delegate: delegate)
      }
  }
choices:
  - text: "startRunning() blocks the main thread until the session runs."
    correct: true
  - text: "It never checks or requests camera authorization."
    correct: true
  - text: "The same AVCapturePhotoSettings instance is reused for every shot, which throws an exception on the second capture."
    correct: true
  - text: "Force unwrapping and try! crash on the simulator (no camera) or on failure, and it adds without canAddInput/canAddOutput or a configuration batch."
    correct: true
  - text: "AVCaptureSession can only be created inside a UIViewController."
    correct: false
    why: "Any object can own a session; the constraint is threading, not where it lives."
rubric:
  - I flagged startRunning on the main thread.
  - I flagged the missing authorization check.
  - I flagged the reused settings.
  - I flagged the crashes and the unchecked, unbatched configuration.
solution: |
  - Move the session into an actor (or a serial queue) so `startRunning()` blocks that, not the UI.
  - Check `AVCaptureDevice.authorizationStatus(for: .video)` and request access when it's `.notDetermined`; show an explanation and a Settings button when denied. The Info.plist needs `NSCameraUsageDescription`.
  - Create `AVCapturePhotoSettings()` inside `shoot`, for every capture.
  - Handle a missing camera and a failing input with errors, check `canAddInput`/`canAddOutput`, and wrap changes in `beginConfiguration()`/`commitConfiguration()`.
  - The lesson's `CameraService` actor does all of these.
````

````exercise
id: m45-l03-e4
type: fill-in
prompt: "Complete the photo loading for Pantry's receipt picker."
code: |
  PhotosPicker(selection: $selection, matching: .[[1]]) {
      Label("Attach Receipt", systemImage: "doc.text.image")
  }
  .task(id: selection) {
      guard let item = selection else { return }
      let data = try? await item.[[2]](type: Data.self)
      guard !Task.[[3]], let data, let image = UIImage(data: data) else { return }
      thumbnail = image.[[4]](of: CGSize(width: 1024, height: 768))
  }
blanks:
  - id: "1"
    answers: ["images"]
  - id: "2"
    answers: ["loadTransferable"]
  - id: "3"
    answers: ["isCancelled"]
  - id: "4"
    answers: ["preparingThumbnail"]
solution: |
  - `.images` filters the picker to images.
  - `loadTransferable(type:)` loads the picked item's data, possibly downloading it from iCloud.
  - `Task.isCancelled` is true when a newer selection restarted the task, so the stale result is dropped.
  - `preparingThumbnail(of:)` avoids decoding the full-size image.

  This compact version ignores errors with `try?`; the lesson's version reports them, which is what the person needs when iCloud is unreachable.
````

````exercise
id: m45-l03-e5
type: solve
prompt: |
  Write `thumbnailSize(for:maxSide:)`. Scale the size down so that its longest side equals `maxSide`, keeping the aspect ratio and rounding each side to the nearest pixel (halves round up). Never scale up: a size that already fits, or a `maxSide` of zero or less, is returned unchanged. No side may become 0. Use integer arithmetic only.

  Expected output:

  ```output
  4032x3024 → 1024x768
  3024x4032 → 768x1024
  1000x333 → 1000x333
  800x600 → 800x600
  12000x10 → 1024x1
  ```
starter: |
  struct PixelSize: Equatable {
      let width: Int
      let height: Int
  }

  func thumbnailSize(for original: PixelSize, maxSide: Int) -> PixelSize {
      // your code
      return original
  }

  let photos = [
      PixelSize(width: 4032, height: 3024),
      PixelSize(width: 3024, height: 4032),
      PixelSize(width: 1000, height: 333),
      PixelSize(width: 800, height: 600),
      PixelSize(width: 12000, height: 10),
  ]
  for photo in photos {
      let size = thumbnailSize(for: photo, maxSide: 1024)
      print("\(photo.width)x\(photo.height) → \(size.width)x\(size.height)")
  }
hints:
  - "Each side becomes side × maxSide ÷ longest."
  - "Adding longest / 2 before the integer division rounds to the nearest whole number."
rubric:
  - Keeps the aspect ratio using the longest side.
  - Rounds to nearest with integer arithmetic.
  - Never upscales, never returns 0, and handles a non-positive maxSide.
solution: |
  ```swift
  struct PixelSize: Equatable {
      let width: Int
      let height: Int
  }

  /// Scales `original` down to fit in a `maxSide` × `maxSide` box, keeping the aspect ratio and
  /// rounding to the nearest pixel. Never scales up, and never returns a zero side.
  func thumbnailSize(for original: PixelSize, maxSide: Int) -> PixelSize {
      let longest = max(original.width, original.height)
      guard longest > maxSide, maxSide > 0 else { return original }
      func scaled(_ side: Int) -> Int {
          max(1, (side * maxSide + longest / 2) / longest)
      }
      return PixelSize(width: scaled(original.width), height: scaled(original.height))
  }

  let photos = [
      PixelSize(width: 4032, height: 3024),
      PixelSize(width: 3024, height: 4032),
      PixelSize(width: 1000, height: 333),
      PixelSize(width: 800, height: 600),
      PixelSize(width: 12000, height: 10),
  ]
  for photo in photos {
      let size = thumbnailSize(for: photo, maxSide: 1024)
      print("\(photo.width)x\(photo.height) → \(size.width)x\(size.height)")
  }
  ```

  ```output
  4032x3024 → 1024x768
  3024x4032 → 768x1024
  1000x333 → 1000x333
  800x600 → 800x600
  12000x10 → 1024x1
  ```

  - 4032 × 3024 is 4:3, so 1024 × 768 exactly; the portrait photo swaps them.
  - Photos that already fit come back unchanged. Upscaling would only add memory and blur.
  - 12000 × 10 would scale the height to 0.85, which rounds to 1; `max(1, ...)` keeps it from ever reaching 0, which an image API would reject.
  - The guard order matters: with `maxSide <= 0`, the function returns before dividing anything.
````

````exercise
id: m45-l03-e6
type: design
prompt: "Design Pantry's 'voice note for the delivery driver' feature: the person records up to 30 seconds, plays it back, and attaches it to the order. Cover permissions and when to ask, the audio session category and activation, what happens to other apps' audio, interruptions while recording or playing, the indication that recording is happening, and what you'd test."
rubric:
  - Asks for microphone permission when the person first taps record, with a specific NSMicrophoneUsageDescription and a fallback (typed note) when denied.
  - Uses playAndRecord set when the feature opens, activated when recording starts, and deactivated afterwards so other audio can resume.
  - Handles interruptions by stopping or pausing the recording and not auto-resuming recording; resumes playback only if it was playing and the system suggests it.
  - Shows a clear recording indicator (guideline 2.5.14) and limits the length.
  - Tests the state logic in plain Swift and the permission, interruption and silent-switch paths on a device.
solution: |
  - **Permission:** `NSMicrophoneUsageDescription` = "Record a voice note for your delivery driver." Ask with `AVAudioApplication.requestRecordPermission()` when the person first taps Record. If denied, show a text field for a typed note and a button to Settings.
  - **Session:** `.playAndRecord`, set when the voice-note sheet opens, `setActive(true)` when recording or playback starts, `setActive(false)` when the sheet closes, so the person's music can come back.
  - **Interruptions:** a call during recording ends the recording and keeps what was captured; recording never restarts on its own. Playback follows the lesson's state machine: resume only if it was playing and the system suggests it.
  - **Indication:** a red recording bar with a running timer and a stop button, as 2.5.14 requires, plus an automatic stop at 30 seconds.
  - **Tests:** the recording state machine (start, stop, interruption, time limit) as plain Swift; on a device: denial, a phone call mid-recording, the Silent switch, and music playing in another app before and after.
````

## Summary

- `PhotosPicker` runs out of process and needs no permission. Load with `loadTransferable(type: Data.self)`, which is async and can fail; use `.task(id:)` so a newer selection cancels an older load; downsize with `preparingThumbnail(of:)`.
- Purpose strings: `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, `NSPhotoLibraryUsageDescription` for full PhotoKit access, `NSPhotoLibraryAddUsageDescription` for saving. Missing keys crash or terminate the app. Guideline 5.1.1(iii) prefers the picker.
- `AVCaptureSession`: check authorization, add input and output inside `beginConfiguration()`/`commitConfiguration()` with `canAdd` checks, and call the blocking `startRunning()` off the main thread. Use new `AVCapturePhotoSettings` for each capture.
- Audio categories: `.ambient` for nonessential sound, `.soloAmbient` is the default, `.playback` for essential sound (plus the audio background mode to continue in the background), `.playAndRecord` for recording. Set the category early and activate when playback starts.
- `AVPlayer` with `VideoPlayer` plays media in SwiftUI; create the player in `.task` and pause on disappear.
- `AVPlayer` pauses itself on interruptions. Resume only if it was playing and the system suggests resuming. Guideline 2.5.14 requires a clear indication while recording.
