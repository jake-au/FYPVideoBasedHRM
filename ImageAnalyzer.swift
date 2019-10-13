//
//  ImageAnalyzer.swift
//  HRM
//
//  Created by Jiakai Ren on 12/9/19.
//  Copyright © 2019 Jiakai Ren. All rights reserved.
//

import Foundation
import UIKit

protocol ImageAnalyzerDelegate: class {
	func didUpdateHR(HR: Double)
}

struct TimedValue {
	let value: Double
	let timestamp: Double
}

open class ImageAnalyzer {
	weak var delegate: ImageAnalyzerDelegate?

	private let maxTime = 30 // How long should the software run for? (In seconds)
	private let windowSize = 10 // How many seconds of data should be used for HR calculation?
	private let hrInterval = 1 // HR update interval in seconds.

	// MARK: - Filter parameters
	// Butterworth lowpass filter of 5th order
	private let a1: [Double] = [1.0, -3.8731, 6.1017, -4.8724, 1.9681, -0.3212]
	private let b1: [Double] = [0.0000961, 0.0004806, 0.0009611, 0.0009611, 0.0004806, 0.0000961]

	// IIR notch filter
	private let a2: [Double] = [1.0, -1.8816, 0.8816]
	private let b2: [Double] = [0.9408, -1.8816, 0.9408]

	private let desiredFrameRate = 30
	private var windowStartPosition: Double { return Double(windowSize * desiredFrameRate) } // Sliding window start time (frames)
	private var totalFrameNumber: Double { return Double(maxTime * desiredFrameRate) }


	private var values: [Double] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
//	private var peaksIndex = [Int](repeating: 0, count: maxTime * 3)
//	private var heartRate = [Float](repeating: 0.0, count: maxTime)
//
	static let maxFilterOrder = 6

	private var gMean: [TimedValue] = []
	private var gMeanF1: [TimedValue] = []
	private var gMeanF2: [TimedValue] = []
	private var peaks: [TimedValue] = []

	var peakCounter = 0
	var frameCounter = 0
	var hrIntervalCounter = 0

	init() {
		// Initialize each array with 6 empty values
		(1...ImageAnalyzer.maxFilterOrder).forEach { _ in
			gMean.append(TimedValue(value: 0, timestamp: 0))
			gMeanF1.append(TimedValue(value: 0, timestamp: 0))
			gMeanF2.append(TimedValue(value: 0, timestamp: 0))
		}
	}

	func addProcessedData(green: CGFloat, timestamp: Double) {
		// Add data into an array, that will contain all the data

		let pFrame = TimedValue(value: Double(green), timestamp: timestamp)

		// Adding new data to the array(at the end)
		gMean.append(pFrame)
		// Remove first element in the array of maxFilterOrder
		gMean.remove(at: 0)
		process()
	}

	private func process() {
		// =========    Filter 1 =====================
		// Discard first gMeanF1 and append a zero
		gMeanF1.remove(at: 0)
		// Calculate value of Filter 1, with timestamp of last frame
		let F1Value = (-a1[1] * gMeanF1[4].value
			- a1[2] * gMeanF1[3].value -
			a1[3] * gMeanF1[2].value -
			a1[4] * gMeanF1[1].value -
			a1[5] * gMeanF1[0].value +
			b1[0] * gMean[5].value +
			b1[1] * gMean[4].value +
			b1[2] * gMean[3].value +
			b1[3] * gMean[2].value +
			b1[4] * gMean[1].value +
			b1[5] * gMean[0].value) / a1[0]
		gMeanF1.append(TimedValue(value: F1Value, timestamp: gMean[5].timestamp))

		// Discard first gMeanF1 and append a zero
		gMeanF2.remove(at: 0)

		// =========    Filter 2 =====================
		let F2Value = (-a2[1] * gMeanF2[4].value
			- a2[2] * gMeanF2[3].value
			+ b2[0] * gMeanF1[5].value
			+ b2[1] * gMeanF1[4].value
			+ b2[2] * gMeanF1[3].value) / a2[0]
		gMeanF2.append(TimedValue(value: F2Value, timestamp: gMeanF1[5].timestamp))

		// Modified find peaks
        
        // && ((gMeanF2[4].timestamp - (peaks.last?.timestamp ?? 0)) >= 600)
        
        if (gMeanF2[4].value >= gMeanF2[3].value) && (gMeanF2[4].value >= gMeanF2[5].value) {
            peaks.append(gMeanF2[4])
        }
        else {
            return
        }
    

		// Remove pic out of 10 seconds span
		guard let lastPeak = peaks.last else {
			// If the array is empty, do nothing and exit
			return
		}

		let minTime = lastPeak.timestamp - 10 * 1000
        
        peaks.removeAll { peak -> Bool in
            return peak.timestamp < minTime
        }

		// Calculate HR
		let numPeaks = peaks.count - 1

		guard let firstPeak = peaks.first else {
			// It should not get here, but can try
			return
		}

		if peaks.count == 1 {
			// If there is just one peak, do nothing
			return
		}

		// Time diff in milliseconds
		let timeDiffMillis = lastPeak.timestamp - firstPeak.timestamp
		let timeDiffSeconds = timeDiffMillis / 1000

		let HR = (Double(numPeaks) / timeDiffSeconds) * 60
		if let delegate = delegate {
			// TODO: put real HR number
			delegate.didUpdateHR(HR: HR)
		}
	}
}
