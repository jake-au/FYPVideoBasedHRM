//
//  FrameProcessor.swift
//  HRM
//
//  Created by Paolo Tagliani on 12/09/2019.
//  Copyright © 2019 Jiakai Ren. All rights reserved.
//

import Foundation
import AVFoundation
import CoreImage
import Vision
import UIKit


// Changedto user face tracking in real time
//https://developer.apple.com/documentation/vision/tracking_the_user_s_face_in_real_time

protocol FrameProcessorDelegate: class {
	func didFoundFaceImage(image: UIImage, timestamp: Double)
	func didDetectFacePosition(boundingBox: CGRect?)
}

class FrameProcessor {

	private let ciContext = CIContext()
	private let dataOutputQueue = DispatchQueue(
		label: "video frane processing queue",
		qos: .userInitiated,
		autoreleaseFrequency: .workItem)

	// Defines the request handler.
	private var sequenceHandler = VNSequenceRequestHandler()
	weak var delegate: FrameProcessorDelegate?

	func processFrameBuffer(sampleBuffer: CMSampleBuffer, timestamp: Double) {
		// Schedule the work asynchronously on the work queue
			self.findFace(sampleBuffer, timestamp)
	}

	private func findFace(_ sampleBuffer: CMSampleBuffer, _ timestamp: Double) {
		// Get the image buffer from the passed in sample buffer
		guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
			return
		}

		let cimage = CIImage(cvImageBuffer: imageBuffer)

		// Face detection request to get a proper image to analyze
		let detectFaceRequest = VNDetectFaceRectanglesRequest { (request, error) in
			// Extract the first result from the array of face observation results.
			guard
				let results = request.results as? [VNFaceObservation],
				let result = results.first
				else {
					return
			}

			let cropImage = cimage.cropped(to: VNImageRectForNormalizedRect(result.boundingBox, Int(cimage.extent.size.width), Int(cimage.extent.size.height)))
			guard let cgImage = self.ciContext.createCGImage(cropImage, from: cropImage.extent) else { return }
			let procImage = UIImage(cgImage: cgImage)

			// Make sure the FaceView is redrawn
			DispatchQueue.main.async {
				if let delegate = self.delegate {
					delegate.didFoundFaceImage(image: procImage, timestamp: timestamp)
				}
			}
//
//			// Get the average color of the croppedImage
//			if let averageColor = procImage.averageColor {
//				var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
//				averageColor.getRed(&r, green: &g, blue: &b, alpha: &a)
//			}
		}

		// Request to get the image and update the current preview
		let previewFaceRequest = VNDetectFaceRectanglesRequest { (request, error) in
			// Extract the first result from the array of face observation results.
			guard
				let results = request.results as? [VNFaceObservation],
				let result = results.first
				else {
					DispatchQueue.main.async {
						if let delegate = self.delegate {
							delegate.didDetectFacePosition(boundingBox: nil)
						}
					}

					return
			}

			// Make sure the FaceView is redrawn
			DispatchQueue.main.async {
				if let delegate = self.delegate {
					delegate.didDetectFacePosition(boundingBox: result.boundingBox)
				}
			}
		}
		//Use previously defined sequence request handler to perform face detection request on the image.
		do {
			try sequenceHandler.perform(
				[detectFaceRequest],
				on: cimage)
		} catch {
//			print(error.localizedDescription)
		}

	}
}
