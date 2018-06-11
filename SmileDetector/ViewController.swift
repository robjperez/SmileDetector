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

    let emitterLayer = CAEmitterLayer()
    lazy var cell: CAEmitterCell = {
        let cell = CAEmitterCell()
        cell.name = "heart"
        cell.birthRate = 3.0
        cell.lifetime = 7.0
        cell.lifetimeRange = 0
        cell.velocity = CGFloat(125.0)
        cell.velocityRange = CGFloat(40)
        cell.emissionLongitude = CGFloat(Double.pi)
        cell.emissionRange = CGFloat(Double.pi / 4)
        cell.spin = CGFloat(1.7)
        cell.spinRange = CGFloat(2.0)
        cell.scaleRange = CGFloat(0.5)
        cell.scaleSpeed = CGFloat(-0.05)
        cell.contents = UIImage(named: "heart")!.cgImage

        return cell
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        let options = VisionFaceDetectorOptions()
        options.modeType = .fast
        options.landmarkType = .all
        options.classificationType = .all
        options.minFaceSize = CGFloat(0.2)
        options.isTrackingEnabled = true
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

        emitterLayer.backgroundColor = UIColor.blue.cgColor
        emitterLayer.emitterPosition = CGPoint(x: view.frame.size.width / 2, y: 0)
        emitterLayer.emitterSize = CGSize(width: view.frame.size.width, height: 1)
        emitterLayer.emitterShape = kCAEmitterLayerLine
        emitterLayer.birthRate = 0
        emitterLayer.emitterCells = [cell]

        view.layer.addSublayer(emitterLayer)
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
        if Date().timeIntervalSince(lastTime) < Double(0.2) {
            // Limit to 5fps
            return
        }

        self.lastTime = Date()
        DispatchQueue.global(qos: .background).async {
            let img = UIImage(pixelBuffer: frame, withRotation: orientation)
            /** Uncomment this if you want to have a preview
              * of the image which is going to be sent to MLKit
            DispatchQueue.main.sync {
                self.sampleImage.isHidden = false
                self.sampleImage.image = img
            }
            */

            if let detector = self.detector {
                let visionImage = VisionImage(image: img)
                detector.detect(in: visionImage) { (faces, err) in
                    if let error = err {
                        print("\(error)")
                        return
                    }

                    if let faceArray = faces, faceArray.count > 0 && faceArray[0].smilingProbability > 0.5 {
                        DispatchQueue.main.async {
                            self.emitterLayer.birthRate = Float(faceArray[0].smilingProbability * 3)
                            self.flagView.isHidden = false
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.emitterLayer.birthRate = 0
                            self.flagView.isHidden = true
                        }
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

