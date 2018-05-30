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
    
    @IBOutlet weak var processedFrame: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let options = VisionFaceDetectorOptions()
        options.modeType = .accurate
        options.landmarkType = .all
        options.classificationType = .all
        options.minFaceSize = CGFloat(0.1)
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
        
        view.bringSubview(toFront: processedFrame)        
    }
}

extension ViewController: VideoCaptureDelegate {
    func frameCaptured(frame: CVPixelBuffer, orientation: UIImageOrientation) {
        if Date().timeIntervalSince(lastTime) < Double(1) {
            return
        }
        
        self.lastTime = Date()
        DispatchQueue.global(qos: .background).async {
            var cgImage: CGImage?
            VTCreateCGImageFromCVPixelBuffer(frame, nil, &cgImage)
            if let cgImage = cgImage, let detector = self.detector  {
                let img = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
                
                DispatchQueue.main.async {
                    self.processedFrame.image = img
                }
                
                let visionImage = VisionImage(image: img)
                detector.detect(in: visionImage) { (faces, err) in
                    if let error = err {
                        print("\(error)")
                    }
                    if let faceArray = faces, faceArray.count > 0 {
                        print("\(faceArray[0].smilingProbability)")
                    }
                    
                    print("\(faces), \(err)")
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

