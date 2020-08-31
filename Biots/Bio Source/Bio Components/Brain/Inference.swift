//
//  Inference.swift
//  Biots
//
//  Created by Robert Silverman on 4/24/20.
//  Copyright © 2020 Rob Silverman. All rights reserved.
//

import Foundation
import OctopusKit
import SpriteKit

struct Inference {
	var thrust = RunningCGVector(memory: 2)
	var color = RunningColorVector(memory: 10)
	var speedBoost = RunningValue(memory: 10)
	var blink = false
	var future: Float = .zero

	/**
 	|     0    |     1    |    2    |    3    |    4    |      5      |   6   |   7    |
	| L thrust | R thrust | color R | color G | color B | speed boost | blink | future |
	*/
	
	static var outputCount: Int {
		return 8
	}
			
	mutating func infer(outputs: [Float]) {
		
		let count = Inference.outputCount
		guard outputs.count == count else {
			OctopusKit.logForSim.add("outputs count != \(count), count given: \(outputs.count)")
			return
		}
		
		// thrust (-1..1, -1..1) x xy
		thrust.addValue(CGVector(dx: outputs[0].cgFloat, dy: outputs[1].cgFloat))
		
		// color (-1..1 --> 0..1) x rgb
		let red = (outputs[2].cgFloat + 1)/2
		let green = (outputs[3].cgFloat + 1)/2
		let blue = (outputs[4].cgFloat + 1)/2
		color.addValue(ColorVector(red: red, green: green, blue: blue))
		
		// speed boost (-1..1 --> 0|1)
		speedBoost.addValue(outputs[5] > 0 ? 1 : 0)
		
		blink = outputs[6] > 0 ? true : false
		
		future = outputs[7]
	}
}
