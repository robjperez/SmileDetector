//
//  ViewController.swift
//  SmileDetector
//
//  Created by Roberto Perez Cubero on 30/05/2018.
//  Copyright © 2018 rpc. All rights reserved.
//

import UIKit
import Firebase
import OpenTok
import VideoToolbox

class ViewController: UIViewController {

    var publisher: OTPublisher?
    var capturer: ExampleVideoCapture?
    var detector: VisionFaceDetector?
    var lastTime = Date()
    @IBOutlet weak var flagView: UIView!
    @IBOutlet weak var sampleImage: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let options = VisionFaceDetectorOptions()
        options.modeType = .accurate
        options.landmarkType = .all
        options.classificationType = .all
        options.minFaceSize = CGFloat(0.1)
        options.isTrackingEnabled = false
        detector = Vision.vision().faceDetector(options: options)
        
        capturer = ExampleVideoCapture()
        
        let pubSettings = OTPublisherSettings()
        pubSettings.videoCapture = capturer!
        capturer!.delegate = self
        publisher = OTPublisher(delegate: self, settings: pubSettings)
        
        if let pubView = publisher?.view {
            view.addSubview(pubView)
            pubView.frame = view.bounds
        }
        
        flagView.isHidden = true
        view.bringSubview(toFront: sampleImage)
        view.bringSubview(toFront: flagView)
    }
}

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

extension ViewController: VideoCaptureDelegate {
    func frameCaptured(frame: CVPixelBuffer, orientation: OTVideoOrientation) {
        if Date().timeIntervalSince(lastTime) < Double(1) {
            return
        }
        self.lastTime = Date()
        
        DispatchQueue.global(qos: .background).async {
            let img = UIImage(pixelBuffer: frame, withRotation: orientation)
            DispatchQueue.main.sync {
                self.sampleImage.image = img
            }
            if let detector = self.detector {                
                let visionImage = VisionImage(image: img)
                let start = DispatchTime.now() // <<<<<<<<<< Start time
                detector.detect(in: visionImage) { (faces, err) in
                    let end = DispatchTime.now() // <<<<<<<<<< Start time
                    
                    let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds // <<<<< Difference in nano seconds (UInt64)
                    let timeInterval = Double(nanoTime) / 1_000_000_000
                    print("Processing time: \(timeInterval)")
                    if let error = err {
                        print("\(error)")
                    }
                    if let faceArray = faces, faceArray.count > 0 {
                        DispatchQueue.main.async {
                            self.flagView.isHidden = faceArray[0].smilingProbability < 0.6
                        }
                        print("\(faceArray[0].smilingProbability)")
                    }
                }
            }
        }
    }
}

extension ViewController: OTPublisherDelegate {
    func publisher(_ publisher: OTPublisherKit, streamCreated stream: OTStream) {
        
    }
    
    func publisher(_ publisher: OTPublisherKit, didFailWithError error: OTError) {
        
    }
}

