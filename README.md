iOS Smile Detector using MLKit
==============================

This small ios sample application uses [Google's MLKit](https://developers.google.com/ml-kit/) to analyze your face and put some nice hearts when you are smiling by using Machine Learning algorithms.

To fetch images from the camera it uses [OpenTok library](https://tokbox.com/developer/sdks/ios/)

Application Setup
-----------------

You will need to create a Firebase project,  download your `GoogleService-info.plist` file containing your project credentials and replace with the empty place holder which lives in `SmileDetector` folder.

When you have your firebase dep solved, please run

```shell
$ pod install
$ open SmileDetector.xcworkspace
```

When Xcode opens the project, click on run and see the cute hearts raining when you smile at the camera.

Code
----

In order to get camera frames from the device when using OpenTok, you need to build a [CustomCapturer](https://tokbox.com/developer/tutorials/ios/custom-camera-video-capturing/), in this sample that is achieved by `ExampleVideoCapture` class.

That capturer will call its delegate whenever it has a frame from the camera passing the `CVPixelBuffer` content of the frame.

For MLKit to recognize the image, we need to convert that CVPixelBuffer to a UIImage, we do that with this code:
```swift
extension UIImage {
  convenience init(pixelBuffer: CVPixelBuffer, withRotation rotation: OTVideoOrientation) {
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
    let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))

    let imgRotation: Double = {
        switch (rotation)
        {
        case .up: return 0
        case .right: return .pi / 2
        case .down: return .pi
        case .left: return -.pi / 2
        }
    }()

    var tx = CGAffineTransform(translationX: width/2.0, y: height/2.0)
    tx = tx.rotated(by: CGFloat(imgRotation))
    tx = tx.translatedBy(x: -width/2, y: -height/2)
    let transformed = ciImage.transformed(by: tx)

    let context = CIContext(options: nil)
    let cgImage = context.createCGImage(transformed, from: CGRect(x: 0, y: 0, width: width, height: height))
    self.init(cgImage: cgImage!, scale: 1.0, orientation: .up)
  }
}
```

It creates the UIImage rotating the Pixel buffer accordingly to the device orientation

Once we have a UIImage, we feed MLKit with it by using:

```swift
let img = UIImage(pixelBuffer: frame, withRotation: orientation)
if let detector = self.detector {
    let visionImage = VisionImage(image: img)
    detector.detect(in: visionImage) { (faces, err) in
      ...
    }
}
```

We will have in `faces` variable the outcome of the detection.