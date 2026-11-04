---
id: m40-l04
title: Wrapping view controllers
description: "UIViewControllerRepresentable is UIViewRepresentable for a whole view controller: an existing UIKit screen, or a system controller like the photo picker or the camera. You pick between PhotosPicker, PHPickerViewController and UIImagePickerController based on what Apple documents for each, wrap the picker and the camera with coordinators, present them from SwiftUI state, dismiss from the side that presented, and model the result in plain Swift so a pick followed by a dismissal is reported exactly once."
module: m40
order: 4
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m40-l03]
objectives:
  - Wrap a UIViewController with UIViewControllerRepresentable and its coordinator.
  - Choose between PhotosPicker, PHPickerViewController and UIImagePickerController for a task.
  - Present a wrapped controller from SwiftUI with sheet or fullScreenCover and dismiss it through state.
  - Pass results back with a closure and report each flow's result exactly once.
  - Bring an existing UIKit screen into a SwiftUI NavigationStack.
terms:
  - term: UIViewControllerRepresentable
    definition: "A SwiftUI protocol for a view that creates and manages a UIViewController: makeUIViewController(context:), updateUIViewController(_:context:), and optionally makeCoordinator(), sizeThatFits(_:uiViewController:context:) and the static dismantleUIViewController(_:coordinator:)."
  - term: PHPickerViewController
    definition: "PhotosUI's photo library picker (iOS 14). Apple presents it as an alternative to UIImagePickerController with better stability and features. Results arrive in picker(_:didFinishPicking:), which also runs on Cancel; the picker doesn't dismiss itself."
  - term: UIImagePickerController
    definition: "UIKit's older picker for taking pictures and movies and choosing from the library. Still the system controller for camera capture; its delegate must dismiss it."
  - term: PhotosPicker
    definition: "The SwiftUI photo picker view (iOS 16). Selections are PhotosPickerItem values you load with loadTransferable(type:). The first choice in a SwiftUI screen that only needs the library."
  - term: One-shot result
    definition: "A flow result that can be delivered only once. The first outcome (picked, cancelled) wins; later reports from other paths, such as a sheet's onDismiss, are ignored."
mastery:
  - Wrap PHPickerViewController with a coordinator that forwards picker(_:didFinishPicking:) to a closure.
  - Wrap UIImagePickerController for the camera, check source availability, and present it full screen.
  - Dismiss a SwiftUI-presented controller by setting its presentation state to false.
  - Predict which result a flow reports when the delegate and the sheet's onDismiss both fire.
  - Push an existing UIKit view controller onto a SwiftUI NavigationStack and wire its closure.
resources: [swiftui-uiviewcontrollerrepresentable, photosui-phpickerviewcontroller, uikit-uiviewcontroller, swiftui-sheet-item, swiftui-navigationstack, requesting-protected-resources, swift-book-closures, swift-book-enumerations]
cards:
  - id: m40-l04-c1
    front: What's the difference between UIViewRepresentable and UIViewControllerRepresentable?
    back: "The second wraps a whole view controller: makeUIViewController(context:) and updateUIViewController(_:context:) instead of makeUIView/updateUIView. Same rules: make once, update idempotently, a coordinator for delegates, SwiftUI owns the view's layout."
  - id: m40-l04-c2
    front: Which picker for which job?
    back: "Library in a SwiftUI screen: PhotosPicker (iOS 16). Library with UIKit or PHPicker features: PHPickerViewController (Apple calls it an alternative to UIImagePickerController, with more benefits). Camera capture: UIImagePickerController with sourceType .camera."
  - id: m40-l04-c3
    front: Does PHPickerViewController dismiss itself when the user taps Add or Cancel?
    back: "No. picker(_:didFinishPicking:) runs for both, and Apple: 'The picker won't be automatically dismissed when this method is called.' If SwiftUI presented it with .sheet, set the isPresented state to false."
  - id: m40-l04-c4
    front: Why make a picker flow's result one-shot?
    back: "Several paths can report the end: the delegate (picked or cancelled) and the sheet's onDismiss (runs after any dismissal). If each reports, a pick can be overwritten by a 'cancelled' from onDismiss. Accept the first outcome and ignore the rest."
  - id: m40-l04-c5
    front: Does a wrapped view controller need a coordinator?
    back: "Only if it reports through a delegate or target-action. If it exposes closure properties (onDone, onShare), set them in updateUIViewController; no coordinator needed."
---

## The idea in one sentence

**`UIViewControllerRepresentable` does for a view controller what lesson 2 did for a view**: SwiftUI creates the controller once, updates it from your values, and a coordinator carries its delegate callbacks back.

> [!note] About this lesson's code
> UIKit, PhotosUI and SwiftUI blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) on the CI runner, not run. Behavior is quoted from Apple's pages for `UIViewControllerRepresentable` and its methods, `PHPickerViewController`, `PHPickerConfiguration`, `selectionLimit`, `filter`, `picker(_:didFinishPicking:)`, `PhotosPicker`, `PhotosPickerItem`, `NSItemProvider.loadTransferable(type:completionHandler:)`, `UIImagePickerController`, its delegate methods and `sheet(isPresented:onDismiss:content:)`, read in November 2026. The result-flow model was compiled and run with Swift 6.3. Nothing was run on a device; camera code in particular needs one.

## The protocol

The method names change from "view" to "view controller"; everything else carries over:

| UIViewRepresentable | UIViewControllerRepresentable |
| --- | --- |
| `makeUIView(context:)` | `makeUIViewController(context:)`, "only once, when it creates your view controller for the first time" |
| `updateUIView(_:context:)` | `updateUIViewController(_:context:)`, "for any changes affecting the corresponding UIKit view controller" |
| `sizeThatFits(_:uiView:context:)` (iOS 16) | `sizeThatFits(_:uiViewController:context:)` (iOS 16) |
| `static dismantleUIView(_:coordinator:)` | `static dismantleUIViewController(_:coordinator:)` |
| `makeCoordinator()` | `makeCoordinator()` |

The same warning applies, about the controller's view this time: "SwiftUI fully controls the layout of the UIKit view controller's view using the view's `center`, `bounds`, `frame`, and `transform` properties."

Reach for it in two situations:

- **A system view controller** that SwiftUI doesn't replace for your case: the camera, a photo picker with options `PhotosPicker` lacks, mail composition, document previews.
- **An existing UIKit screen** you want to show from a SwiftUI flow while it waits its turn to be rewritten (lesson 6).

## Which photo picker

Three candidates, and Apple's pages are clear about their roles:

- **`PhotosPicker`** (SwiftUI, iOS 16): "A view that displays a Photos picker for choosing assets from the photo library." Its selections are `PhotosPickerItem` placeholders that you load with `loadTransferable(type:)`. In a SwiftUI screen that just needs pictures from the library, start here. No wrapper needed.
- **`PHPickerViewController`** (PhotosUI, iOS 14): "The `PHPickerViewController` class is an alternative to `UIImagePickerController`. `PHPickerViewController` improves stability and reliability, and includes several benefits to developers and users," among them "Deferred image loading and recovery UI" and "Reliable handling of large and complex assets, like RAW and panoramic images." This is the library picker for UIKit, and the one to wrap when your SwiftUI screen needs its configuration options.
- **`UIImagePickerController`** (UIKit, iOS 2): "manages the system interfaces for taking pictures, recording movies, and choosing items from the user's media library." It isn't deprecated, but for the library Apple now points to PHPicker as the better choice. Its remaining job is the **camera**: `sourceType = .camera`.

One rule both picker pages share: in iOS 17 and later the picker ignores touches "while its opacity is anything other than fully opaque." Don't fade or dim it.

## Wrapping PHPickerViewController

```swift ios
import CoreTransferable
import Observation
import PhotosUI
import SwiftUI
import UIKit

struct PhotoPicker: UIViewControllerRepresentable {
    var selectionLimit = 1
    let onFinish: ([PHPickerResult]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = selectionLimit
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        context.coordinator.onFinish = onFinish
    }

    @MainActor
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var onFinish: ([PHPickerResult]) -> Void

        init(onFinish: @escaping ([PHPickerResult]) -> Void) {
            self.onFinish = onFinish
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            onFinish(results)
        }
    }
}

@MainActor
@Observable
final class AvatarModel {
    var image: UIImage?

    func load(from provider: NSItemProvider) {
        _ = provider.loadTransferable(type: Data.self) { [weak self] result in
            guard case .success(let data) = result else { return }
            Task { @MainActor in
                self?.image = UIImage(data: data)
            }
        }
    }
}

struct AvatarEditor: View {
    @State private var model = AvatarModel()
    @State private var isPickerPresented = false

    var body: some View {
        VStack(spacing: 16) {
            avatar
            Button("Choose Photo") {
                isPickerPresented = true
            }
        }
        .sheet(isPresented: $isPickerPresented) {
            PhotoPicker(onFinish: finishPicking)
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let image = model.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 120)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 120))
                .foregroundStyle(.secondary)
        }
    }

    private func finishPicking(_ results: [PHPickerResult]) {
        isPickerPresented = false
        if let provider = results.first?.itemProvider {
            model.load(from: provider)
        }
    }
}
```

Line by line:

- **`PHPickerConfiguration`** is a struct you fill in before creating the picker. `filter`: "By default, a configuration object displays all asset types: images, Live Photos, and videos"; `.images` narrows it. `selectionLimit`: "The default value is `1`. Setting the value to `0` sets the selection limit to the maximum that the system supports."
- **`picker.delegate = context.coordinator`**, once, in `makeUIViewController`. The delegate is `weak`; SwiftUI keeps the coordinator.
- **`picker(_:didFinishPicking:)`** is the only delegate method. Apple: "Called when the user completes a selection or dismisses `PHPickerViewController` using the cancel button." There's no separate cancel callback, so an empty `results` array is how "nothing chosen" arrives, whatever the reason.
- **The picker doesn't close itself.** From the same page: "The picker won't be automatically dismissed when this method is called." SwiftUI presented it with `.sheet(isPresented:)`, so `finishPicking` closes it the SwiftUI way: `isPickerPresented = false`.
- **`updateUIViewController`** only refreshes the closure, for the reason lesson 3 gave. A `PHPickerViewController` is configured at creation; to change its configuration, present a new one.
- **Loading.** Each `PHPickerResult` has an `itemProvider` ("Representations of the selected asset"). `loadTransferable(type:completionHandler:)` loads it asynchronously; its completion handler is `@Sendable` and may run off the main thread, so the model hops back with `Task { @MainActor in … }` before touching `image`. `Data` is `Sendable`, so it can cross. The model is `@MainActor`, which also makes it `Sendable` and safe to capture weakly in that closure.
- `avatar` is a separate property, and `finishPicking` a named method, so `body` stays short.

### Who dismisses

Module 25's rule was "the presenter dismisses". Across the boundary it becomes **the side that presented dismisses, in its own terms**:

- SwiftUI presented it (`.sheet`, `.fullScreenCover`): set the state to `false`.
- UIKit presented it (`present(_:animated:)`): call `dismiss(animated:)` on the presenter.

Calling `picker.dismiss(animated: true)` on a controller SwiftUI presented closes it behind SwiftUI's back, and SwiftUI's handling of that isn't something Apple's pages describe. Changing the state keeps one source of truth for "is the picker showing?".

## The camera with UIImagePickerController

```swift ios
import SwiftUI
import UIKit

struct CameraCapture: UIViewControllerRepresentable {
    let onFinish: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        context.coordinator.onFinish = onFinish
    }

    @MainActor
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var onFinish: (UIImage?) -> Void

        init(onFinish: @escaping (UIImage?) -> Void) {
            self.onFinish = onFinish
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            onFinish(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}

struct ReceiptScanner: View {
    @State private var isCameraPresented = false
    @State private var capturedImage: UIImage?

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        Button("Photograph Receipt") {
            isCameraPresented = true
        }
        .disabled(!isCameraAvailable)
        .fullScreenCover(isPresented: $isCameraPresented) {
            CameraCapture(onFinish: finishCapture)
                .ignoresSafeArea()
        }
    }

    private func finishCapture(_ image: UIImage?) {
        isCameraPresented = false
        if let image {
            capturedImage = image
        }
    }
}
```

- **Two protocols.** `UIImagePickerController.delegate` is typed `UIImagePickerControllerDelegate & UINavigationControllerDelegate`, because the picker is a navigation controller subclass. The coordinator conforms to both, even though it implements no navigation methods.
- **Two outcomes, two methods.** `imagePickerController(_:didFinishPickingMediaWithInfo:)` delivers a dictionary; `.originalImage` holds the photo. `imagePickerControllerDidCancel(_:)` covers Cancel. Both pages say the delegate is responsible for dismissing: "should then dismiss the picker view." Here, again, that means setting SwiftUI's state.
- **Availability first.** Apple's first step: "Verify that the device is capable of picking content from the desired source" with `isSourceTypeAvailable(_:)`. The simulator has no camera, so the button is disabled there.
- **Full screen.** Apple: "Apple recommends that you present the camera interface only full screen." `.fullScreenCover` is SwiftUI's full-screen presentation.
- **Permission.** Using the camera requires an `NSCameraUsageDescription` entry in Info.plist. Module 21, lesson 4 quoted what happens without it: access fails, and AVFoundation's docs say "the system terminates your app."

## Results, exactly once

A flow presented as a sheet has more than one way to end. The delegate reports a pick or a cancel. The user may swipe the sheet down; Apple's pages don't say whether the picker's delegate runs in that case. And `.sheet(isPresented:onDismiss:content:)` has an `onDismiss`, "The closure to execute when dismissing the sheet", which runs whichever way the sheet went away.

If every path reports a result, you get bugs like "the user picked a photo and the screen says cancelled": the delegate says "picked", the app sets `isPresented = false`, the sheet goes away, `onDismiss` says "cancelled", and the second report wins. The fix is a flow object that **accepts the first outcome and ignores the rest**. Modeled in plain Swift:

```swift
enum PickOutcome: Equatable {
    case picked(count: Int)
    case cancelled
}

final class PickFlow {
    let oneShot: Bool
    private(set) var reported: [PickOutcome] = []

    init(oneShot: Bool) {
        self.oneShot = oneShot
    }

    // picker(_:didFinishPicking:) — Add and Cancel both arrive here.
    func pickerFinished(resultCount: Int) {
        report(resultCount == 0 ? .cancelled : .picked(count: resultCount))
    }

    // The sheet's onDismiss, which runs after any dismissal.
    func sheetDismissed() {
        report(.cancelled)
    }

    var finalOutcome: PickOutcome? {
        reported.last
    }

    private func report(_ outcome: PickOutcome) {
        if oneShot && !reported.isEmpty {
            return
        }
        reported.append(outcome)
    }
}

func describe(_ outcome: PickOutcome?) -> String {
    switch outcome {
    case .picked(let count)?: return "picked \(count)"
    case .cancelled?: return "cancelled"
    case nil: return "nothing"
    }
}

for oneShot in [false, true] {
    let tappedAdd = PickFlow(oneShot: oneShot)
    tappedAdd.pickerFinished(resultCount: 2)
    tappedAdd.sheetDismissed()

    let tappedCancel = PickFlow(oneShot: oneShot)
    tappedCancel.pickerFinished(resultCount: 0)
    tappedCancel.sheetDismissed()

    let swipedDown = PickFlow(oneShot: oneShot)
    swipedDown.sheetDismissed()

    print("one-shot \(oneShot):", describe(tappedAdd.finalOutcome), "|", describe(tappedCancel.finalOutcome), "|", describe(swipedDown.finalOutcome))
    print("  reports:", tappedAdd.reported.count, tappedCancel.reported.count, swipedDown.reported.count)
}
```

```output
one-shot false: cancelled | cancelled | cancelled
  reports: 2 2 1
one-shot true: picked 2 | cancelled | cancelled
  reports: 1 1 1
```

Read the first line: **without the rule, the Add path ends as "cancelled"**. The delegate reported "picked 2", the sheet's `onDismiss` reported "cancelled" right after, and the last report won. The second line shows it reported twice, so code that reacts to each report (save the photos, then show "No photo selected") runs twice with contradicting outcomes. With the rule, every path reports exactly once and the Add path keeps its pick. Cancel and swipe-down end as "cancelled" either way.

## An existing UIKit screen in a SwiftUI stack

The other common use: a SwiftUI app (or a SwiftUI flow inside a UIKit app) that needs to show a screen nobody has rewritten yet. If the controller reports through **closures**, it doesn't need a coordinator at all; the representable sets the closures in `updateUIViewController`:

```swift ios
import SwiftUI
import UIKit

final class ReceiptViewController: UIViewController {
    let receiptID: String
    var onShare: ((String) -> Void)?

    init(receiptID: String) {
        self.receiptID = receiptID
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("ReceiptViewController is created in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let shareButton = UIButton(type: .system, primaryAction: UIAction(title: "Share") { [weak self] _ in
            guard let self else { return }
            self.onShare?(self.receiptID)
        })
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(shareButton)
        NSLayoutConstraint.activate([
            shareButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shareButton.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}

struct ReceiptScreen: UIViewControllerRepresentable {
    let receiptID: String
    let onShare: (String) -> Void

    func makeUIViewController(context: Context) -> ReceiptViewController {
        ReceiptViewController(receiptID: receiptID)
    }

    func updateUIViewController(_ uiViewController: ReceiptViewController, context: Context) {
        uiViewController.onShare = onShare
    }
}

struct OrdersView: View {
    let receiptIDs = ["R-1042", "R-1043"]
    @State private var lastShared: String?

    var body: some View {
        NavigationStack {
            List(receiptIDs, id: \.self) { id in
                NavigationLink(id, value: id)
            }
            .navigationTitle("Orders")
            .navigationDestination(for: String.self, destination: receiptScreen)
        }
    }

    private func receiptScreen(for id: String) -> some View {
        ReceiptScreen(receiptID: id, onShare: share)
            .navigationTitle("Receipt \(id)")
            .id(id)
    }

    private func share(_ receiptID: String) {
        lastShared = receiptID
    }
}
```

- **No coordinator.** The controller exposes `onShare`, a closure property. Assigning it in `updateUIViewController` keeps it current, the same job `parent = self` did in lesson 3.
- **`receiptID` is a `let`** on the controller, set at creation. If the representable could get a different id, `.id(id)` gives it a new identity, so SwiftUI makes a new controller instead of updating the old one with a value it can't take.
- **The title comes from SwiftUI.** SwiftUI's `NavigationStack` owns this bar, so `.navigationTitle` goes on the representable. Whether the wrapped controller's own `navigationItem` (title, bar button items) shows up in SwiftUI's bar wasn't verified for this lesson; don't rely on it.
- **`navigationDestination(for:destination:)`** takes a function, `receiptScreen(for:)`, rather than an inline closure, which keeps the `body` expression small.

## Common mistakes

> [!error] Waiting for PHPickerViewController to dismiss itself
> It doesn't. "The picker won't be automatically dismissed when this method is called." Set the presentation state to `false` in your result handler.

> [!error] Treating a sheet's onDismiss as "the user cancelled"
> `onDismiss` runs after every dismissal, including the one you triggered after a successful pick. Make the flow's result one-shot, or only use `onDismiss` for clean-up that's right in every case.

> [!error] Using UIImagePickerController for the photo library
> It works, but Apple describes `PHPickerViewController` as the alternative with better stability and more features, and SwiftUI has `PhotosPicker`. Keep `UIImagePickerController` for the camera.

> [!error] Presenting the camera without checking availability
> `isSourceTypeAvailable(.camera)` is false in the simulator and on devices without a usable camera. Check before offering the action, and include `NSCameraUsageDescription`.

> [!error] Touching main-actor state from the item provider's completion handler
> `loadTransferable(type:completionHandler:)` takes a `@Sendable` handler that isn't on the main actor. Carry `Sendable` data (`Data`) out and hop with `Task { @MainActor in … }`.

## Exercises

````exercise
id: m40-l04-e1
type: comprehension
prompt: "A SwiftUI expense app needs two features: attach up to five receipts from the photo library, and photograph a new receipt. Which combination fits Apple's documentation best?"
choices:
  - text: "PhotosPicker with a selection limit of 5 for the library, and a wrapped UIImagePickerController with sourceType .camera for the photo."
    correct: true
    why: "PhotosPicker is SwiftUI's library picker; the camera is UIImagePickerController's remaining job."
  - text: "A wrapped UIImagePickerController for both, with sourceType switched between .photoLibrary and .camera."
    correct: false
    why: "It works, but for the library Apple describes PHPicker as the more stable alternative, and SwiftUI has PhotosPicker."
  - text: "PHPickerViewController for both, configured with a camera filter."
    correct: false
    why: "PHPicker chooses from the library. It doesn't capture photos."
  - text: "PhotosPicker for both."
    correct: false
    why: "PhotosPicker displays the library; it doesn't take pictures."
solution: |
  **PhotosPicker plus a wrapped camera.** `PhotosPicker` "displays a Photos picker for choosing assets from the photo library" and supports multiple selection, so it needs no wrapper in a SwiftUI app. Capturing a new photo is what `UIImagePickerController` with `sourceType = .camera` is for, wrapped with `UIViewControllerRepresentable`, checked with `isSourceTypeAvailable(.camera)` and presented full screen. If the library picker needed `PHPickerConfiguration` options that `PhotosPicker` doesn't offer, wrapping `PHPickerViewController` would be the next step.
````

````exercise
id: m40-l04-e2
type: prediction
prompt: "The PickFlow model from the lesson, but this time the sheet's onDismiss reports before the delegate. What does it print?"
code: |
  enum PickOutcome: Equatable {
      case picked(count: Int)
      case cancelled
  }

  final class PickFlow {
      let oneShot: Bool
      private(set) var reported: [PickOutcome] = []

      init(oneShot: Bool) {
          self.oneShot = oneShot
      }

      func pickerFinished(resultCount: Int) {
          report(resultCount == 0 ? .cancelled : .picked(count: resultCount))
      }

      func sheetDismissed() {
          report(.cancelled)
      }

      private func report(_ outcome: PickOutcome) {
          if oneShot && !reported.isEmpty {
              return
          }
          reported.append(outcome)
      }
  }

  func name(_ outcome: PickOutcome) -> String {
      switch outcome {
      case .picked(let count): return "picked \(count)"
      case .cancelled: return "cancelled"
      }
  }

  let flow = PickFlow(oneShot: false)
  flow.sheetDismissed()
  flow.pickerFinished(resultCount: 2)
  print(flow.reported.map(name))
  print(flow.reported.first == .cancelled, flow.reported.last == .cancelled)

  let guarded = PickFlow(oneShot: true)
  guarded.sheetDismissed()
  guarded.pickerFinished(resultCount: 2)
  print(guarded.reported.map(name))
output: |
  ["cancelled", "picked 2"]
  true false
  ["cancelled"]
hints:
  - "This time onDismiss runs first."
  - "The one-shot flow keeps whatever arrives first, right or wrong."
solution: |
  ```output
  ["cancelled", "picked 2"]
  true false
  ["cancelled"]
  ```

  The order is reversed compared with the lesson: the sheet's `onDismiss` reports first, then the delegate reports a pick.

  - **Without the rule**, both are recorded. The last one is "picked 2", so code that reads the latest report gets the right answer here and the wrong one in the lesson's order. The outcome depends on timing.
  - **With the rule**, the first report wins, and the first report is "cancelled": the user's two photos are lost.

  So "accept the first" is only correct if the path that knows the answer reports first. With PHPicker that's the normal case: your result handler is what sets `isPresented = false`, so the delegate runs before the dismissal that triggers `onDismiss`. When a dismissal can come first (the user swipes the sheet down, and Apple's pages don't say whether the picker reports afterwards), treat the delegate as authoritative and let `onDismiss` report "cancelled" only if nothing has arrived by then.
````

````exercise
id: m40-l04-e3
type: fill-in
prompt: "Complete the photo picker wrapper: up to three images, delegate through the coordinator, and dismissal through SwiftUI state."
code: |
  func makeUIViewController(context: Context) -> PHPickerViewController {
      var configuration = [[1]]()
      configuration.filter = .images
      configuration.[[2]] = 3
      let picker = PHPickerViewController(configuration: configuration)
      picker.delegate = context.[[3]]
      return picker
  }

  // In the coordinator:
  func picker(_ picker: PHPickerViewController, [[4]] results: [PHPickerResult]) {
      onFinish(results)
  }

  // In the SwiftUI view that presented it with .sheet(isPresented: $isPickerPresented):
  private func finishPicking(_ results: [PHPickerResult]) {
      isPickerPresented = [[5]]
      attachments = results.map(\.itemProvider)
  }
blanks:
  - id: "1"
    answers: ["PHPickerConfiguration"]
  - id: "2"
    answers: ["selectionLimit"]
  - id: "3"
    answers: ["coordinator"]
  - id: "4"
    answers: ["didFinishPicking"]
  - id: "5"
    answers: ["false"]
hints:
  - "The configuration is a struct you create before the picker."
  - "The picker doesn't dismiss itself."
solution: |
  `PHPickerConfiguration()` with `selectionLimit = 3` (the default is 1; 0 means the system maximum). The delegate is `context.coordinator`, and the one delegate method is `picker(_:didFinishPicking:)`, called for Add and for Cancel. Because "the picker won't be automatically dismissed", the SwiftUI side sets `isPickerPresented = false`. On Cancel, `results` is empty and `attachments` becomes an empty array; if you'd rather keep earlier attachments on Cancel, check `results.isEmpty` first.
````

````exercise
id: m40-l04-e4
type: solve
prompt: |
  Write a reusable one-shot result relay in plain Swift, for any flow that can end through several paths:

  - `final class ResultRelay<Value>` with an initializer that takes `onResult: (Value) -> Void`.
  - `func deliver(_ value: Value)`: calls `onResult` the first time only; later calls are ignored.
  - `var isFinished: Bool`.

  Then model a camera flow with `enum CaptureResult { case photo(String), cancelled }`: deliver `.photo("IMG_0001")` from the delegate, then `.cancelled` from the cover's `onDismiss`, and print what the app received and `isFinished`. Do the same for a flow where only `onDismiss` runs.
starter: |
  final class ResultRelay<Value> {
      // your code
  }

  enum CaptureResult {
      case photo(String)
      case cancelled
  }
hints:
  - "Keep a private Bool, or store the delivered value in an optional."
  - "The relay doesn't need Value to be Equatable."
rubric:
  - The relay is generic and calls onResult at most once.
  - isFinished reflects whether a value was delivered.
  - The first flow receives the photo and ignores the later cancellation.
  - The second flow receives the cancellation.
solution: |
  ```swift
  final class ResultRelay<Value> {
      private let onResult: (Value) -> Void
      private(set) var isFinished = false

      init(onResult: @escaping (Value) -> Void) {
          self.onResult = onResult
      }

      func deliver(_ value: Value) {
          guard !isFinished else { return }
          isFinished = true
          onResult(value)
      }
  }

  enum CaptureResult {
      case photo(String)
      case cancelled
  }

  final class ScannerScreen {
      private(set) var received: [String] = []

      func record(_ result: CaptureResult) {
          switch result {
          case .photo(let name): received.append("photo \(name)")
          case .cancelled: received.append("cancelled")
          }
      }
  }

  let screen = ScannerScreen()
  let captured = ResultRelay<CaptureResult>(onResult: screen.record)
  captured.deliver(.photo("IMG_0001"))   // imagePickerController(_:didFinishPickingMediaWithInfo:)
  captured.deliver(.cancelled)           // fullScreenCover's onDismiss
  print(screen.received, captured.isFinished)

  let otherScreen = ScannerScreen()
  let dismissedOnly = ResultRelay<CaptureResult>(onResult: otherScreen.record)
  dismissedOnly.deliver(.cancelled)
  print(otherScreen.received, dismissedOnly.isFinished)
  ```

  ```output
  ["photo IMG_0001"] true
  ["cancelled"] true
  ```

  The relay doesn't care which path is first: the delegate, `onDismiss`, an error, a timeout. In the app, create one relay per presentation (for example when the button sets `isCameraPresented = true`), call `deliver` from every path, and the rest of the screen sees one result. `screen.record` passes a method as the closure; in a UIKit screen you'd write `{ [weak self] in self?.record($0) }` so the relay doesn't keep the screen alive (lesson 1). Exercise 2 shows the limit of "first wins": it's only right when the path that knows the answer reports first.
````

````exercise
id: m40-l04-e5
type: find-errors
prompt: "A wrapper for the photo library picker, presented with .sheet(isPresented: $showPicker). Which of these are real problems?"
code: |
  struct LibraryPicker: UIViewControllerRepresentable {
      @Binding var images: [UIImage]

      func makeCoordinator() -> Coordinator {
          Coordinator(images: $images)
      }

      func makeUIViewController(context: Context) -> UIImagePickerController {
          let picker = UIImagePickerController()
          picker.sourceType = .photoLibrary
          picker.delegate = context.coordinator
          picker.view.alpha = 0.95
          return picker
      }

      func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

      @MainActor
      final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
          var images: Binding<[UIImage]>

          init(images: Binding<[UIImage]>) {
              self.images = images
          }

          func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
              if let image = info[.originalImage] as? UIImage {
                  images.wrappedValue.append(image)
              }
          }
      }
  }
choices:
  - text: "For the photo library, PHPickerViewController (or PhotosPicker in SwiftUI) is Apple's recommended alternative."
    correct: true
    why: "Apple lists stability, reliability and feature benefits for PHPicker over UIImagePickerController."
  - text: "Setting the picker's view alpha below 1 makes it ignore touches on iOS 17 and later."
    correct: true
    why: "Both picker pages: it ignores touch events while its opacity isn't fully opaque."
  - text: "Nothing dismisses the picker after a pick, and there's no cancel handler."
    correct: true
    why: "The delegate must dismiss. With a SwiftUI sheet, pass a way to set showPicker to false and implement imagePickerControllerDidCancel(_:)."
  - text: "updateUIViewController doesn't refresh the coordinator's binding."
    correct: true
    why: "Assign context.coordinator.images = $images so the coordinator writes through the current binding."
  - text: "The coordinator must not conform to UINavigationControllerDelegate."
    correct: false
    why: "The picker's delegate type requires both protocols."
rubric:
  - Recommends PHPicker or PhotosPicker for the library.
  - Flags the alpha.
  - Flags the missing dismissal and cancel handling.
  - Flags the binding that's never refreshed.
  - Doesn't flag the UINavigationControllerDelegate conformance.
solution: |
  Four real problems. A corrected version for a SwiftUI screen would use `PhotosPicker` directly, or this wrapper of `PHPickerViewController`:

  ```swift ios
  import PhotosUI
  import SwiftUI
  import UIKit

  struct LibraryPicker: UIViewControllerRepresentable {
      let onFinish: ([PHPickerResult]) -> Void

      func makeCoordinator() -> Coordinator {
          Coordinator(onFinish: onFinish)
      }

      func makeUIViewController(context: Context) -> PHPickerViewController {
          var configuration = PHPickerConfiguration()
          configuration.filter = .images
          configuration.selectionLimit = 0
          let picker = PHPickerViewController(configuration: configuration)
          picker.delegate = context.coordinator
          return picker
      }

      func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
          context.coordinator.onFinish = onFinish
      }

      @MainActor
      final class Coordinator: NSObject, PHPickerViewControllerDelegate {
          var onFinish: ([PHPickerResult]) -> Void

          init(onFinish: @escaping ([PHPickerResult]) -> Void) {
              self.onFinish = onFinish
          }

          func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
              onFinish(results)
          }
      }
  }

  struct GalleryEditor: View {
      @State private var showPicker = false
      @State private var pickedCount = 0

      var body: some View {
          Button("Add Photos (\(pickedCount))") {
              showPicker = true
          }
          .sheet(isPresented: $showPicker) {
              LibraryPicker(onFinish: finishPicking)
          }
      }

      private func finishPicking(_ results: [PHPickerResult]) {
          showPicker = false
          pickedCount += results.count
      }
  }
  ```

  The picker is fully opaque, the one delegate method covers Add and Cancel, the SwiftUI side dismisses by state, and the closure is refreshed on every update. `selectionLimit = 0` means "the maximum that the system supports". The `UINavigationControllerDelegate` conformance in the original was required, not a mistake.
````

## Summary

- `UIViewControllerRepresentable` wraps a view controller with `makeUIViewController`, `updateUIViewController`, an optional coordinator, `sizeThatFits(_:uiViewController:context:)` (iOS 16) and a static `dismantleUIViewController`. Lesson 2's and 3's rules carry over unchanged.
- For the photo library in SwiftUI, use `PhotosPicker`; wrap `PHPickerViewController` when you need its configuration; keep `UIImagePickerController` for the camera, after `isSourceTypeAvailable(.camera)`, presented full screen, with `NSCameraUsageDescription`.
- `picker(_:didFinishPicking:)` handles both Add and Cancel, and the picker doesn't dismiss itself. The image picker's delegate must dismiss too.
- The side that presented dismisses in its own terms: SwiftUI state for `.sheet` and `.fullScreenCover`, `dismiss(animated:)` for UIKit presentations.
- A flow that can end through several paths (delegate, `onDismiss`) should report one result: accept the first and ignore the rest.
- An existing UIKit screen that reports through closures needs no coordinator: set the closures in `updateUIViewController`, give it a new identity with `.id` when its fixed inputs change, and configure the bar from SwiftUI.
