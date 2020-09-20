//
//  Genome.swift
//  BioGenesis
//
//  Created by Robert Silverman on 4/15/20.
//  Copyright © 2020 Rob Silverman. All rights reserved.
//

import Foundation
import OctopusKit
import SpriteKit

struct Genome: CustomStringConvertible, Codable {
	
	static let minMutationIterations = 180
	static let maxMutationIterations = 360

	var id: String
	var marker1 = false
	var marker2 = false
	var generation: Int

	// neural net
	var inputCount: Int
	var hiddenCount: Int
    var outputCount: Int
	var weights: [[Float]] = [[]]
	var biases: [[Float]] = [[]]
	
	func markerValue(index: Int) -> Bool {
		switch index {
		case 0: return marker1
		case 1: return marker2
		default: return false
		}
	}
	
	// new genome
	init(inputCount: Int, hiddenCount: Int, outputCount: Int) {
		self.inputCount = inputCount
		self.hiddenCount = hiddenCount
		self.outputCount = outputCount

		id = UUID().uuidString
		generation = 0
		
		if Constants.Env.markersInEffect > 0 {
			self.marker1 = Bool.random()
		}
		
		if Constants.Env.markersInEffect > 1 {
			self.marker2 = Bool.random()
		}

		let randomized = initialWeightsAndBiases(random: false, initialValue: 0)
		weights = randomized.weights
		biases = randomized.biases
		let mutationIterations = Int.random(min: Genome.minMutationIterations, max: Genome.maxMutationIterations)
		for _ in 0..<mutationIterations {
			mutate()
		}
//		print("created genome:")
//		print(jsonString)
	}
	
	// new genome from parent
	init(parent: Genome) {
		id = UUID().uuidString
		generation = parent.generation + 1
			
		if Constants.Env.markersInEffect > 0, Int.oneChanceIn(3) {
			marker1.toggle()
		}
		if Constants.Env.markersInEffect > 1, Int.oneChanceIn(3) {
			marker2.toggle()
		}

		inputCount = parent.inputCount
		hiddenCount = parent.hiddenCount
		outputCount = parent.outputCount
		weights = parent.weights
		biases = parent.biases

		mutate()
	}
	
	var idFormatted: String {
		return id.truncated(8, trailing: "")
	}
	
	var description: String {
		return "{id: \(idFormatted), markers: \(marker1)|\(marker2), gen: \(generation), inputCount: \(inputCount), hiddenCount: \(hiddenCount), outputCount: \(outputCount)}"
	}

	var jsonString: String {
		let json =
		"""
		{
			"id": "\(id)",
			"marker1": "\(marker1)",
			"marker2": "\(marker2)",
			"generation": \(generation),
			"inputCount": \(inputCount),
			"hiddenCount": \(hiddenCount),
			"outputCount": \(outputCount),
			"weights": \(weights),
			"biases": \(biases)
		}
		"""
		return json
	}
}

extension Genome {

	mutating func mutate() {
		let mutationRate = generation > 50 ? (generation > 200 ? 2 : 3) : 4
		let weightsChances = Int.random(mutationRate)
		let biasesChances = Bool.random() ? 0 : 1
		
		if weightsChances + biasesChances > 0 {
			for _ in 0..<weightsChances { mutateWeights() }
			for _ in 0..<biasesChances { mutateBiases() }
		}
	}
		
	mutating func mutateWeights() {
		
		//todo: this only handles 1 hidden layer
		if Int.oneChanceIn(3) {
			// mutate output layer weights
			if weights.count > 2 && weights[2].count > 0 {
				let randomIndex = Int.random(weights[2].count)
				let mutatedWeight = mutateWeight(weights[2][randomIndex])
				//print("--- mutating output weight of \(id) from: \(weights[2][randomIndex]) to \(mutatedWeight)")
				weights[2][randomIndex] = mutatedWeight
			}
			else {
				OctopusKit.logForSim.add("could not mutate output weights of \(id)")
			}
		}
		else {
			// mutate hidden layer weights
			if weights.count > 1 && weights[1].count > 0 {
				let randomIndex = Int.random(weights[1].count)
				let mutatedWeight = mutateWeight(weights[1][randomIndex])
				//print("--- mutating hidden weight of \(id) from: \(weights[1][randomIndex]) to \(mutatedWeight)")
				weights[1][randomIndex] = mutatedWeight
			}
			else {
				OctopusKit.logForSim.add("could not mutate hidden weights of \(id)")
			}
		}
	}
	
	mutating func mutateBiases() {

		//todo: this only handles 1 hidden layer
		if Int.oneChanceIn(3) {
			// mutate output biases
			if biases.count > 2 && biases[2].count > 0 {
				let randomIndex = Int.random(biases[2].count)
				let mutatedWeight = mutateWeight(biases[2][randomIndex])
				//print("--- mutating output bias of \(id) from: \(biases[2][randomIndex]) to \(mutatedWeight)")
				biases[2][randomIndex] = mutatedWeight
			}
			else {
				OctopusKit.logForSim.add("could not mutate output biases of \(id)")
			}
		}
		else {
			// mutate hidden biases
			if biases.count > 1 && biases[1].count > 0 {
				let randomIndex = Int.random(biases[1].count)
				let mutatedWeight = mutateWeight(biases[1][randomIndex])
				//print("--- mutating hidden bias of \(id) from: \(biases[1][randomIndex]) to \(mutatedWeight)")
				biases[1][randomIndex] = mutatedWeight
			}
			else {
				OctopusKit.logForSim.add("could not mutate hidden biases of \(id)")
			}
		}
	}
	
	func mutateWeight(_ weight: Float) -> Float {
		
		let selector = Int.random(6)
		let max: CGFloat = 1
		
		let minMutationRate: CGFloat = 0.25
		let maxMutationRate: CGFloat = 0.5
		
		switch selector {
		case 0: return weight / 2
		case 1: return Float(CGFloat(weight * 2).clamped(-max, max))
		case 2: return Float.random(in: -Float(max)...Float(max))
		// 50% chance
		default: return Float((CGFloat(weight) + (CGFloat.random(in: minMutationRate..<maxMutationRate) * Int.randomSign.cgFloat)).clamped(-max, max))
		}
	}
	
	func initialWeightsAndBiases(random: Bool = false, initialValue: Float = 0) -> (weights: [[Float]], biases: [[Float]]) {
		
		//todo: this only handles 1 hidden layer
		var randomizedHiddenLayer: [Float] = []
		var randomizedLastLayer: [Float] = []
		var randomizedHiddenBiases: [Float] = []
		var randomizedOutputBiases: [Float] = []
		
		let min: Float = 0
		let max: Float = 1
		
		let inputCount = self.inputCount
		let hiddenCount = self.hiddenCount
		let outputCount = self.outputCount

		for _ in 1...inputCount * hiddenCount {
			let value = random ? Float.random(in: min...max) : initialValue
			randomizedHiddenLayer.append(value)
		}
		
		for _ in 1...hiddenCount * outputCount {
			let value = random ? Float.random(in: min...max) : initialValue
			randomizedLastLayer.append(value)
		}
		
		for _ in 1...hiddenCount {
			let value = random ? Float.random(in: min...max) : initialValue
			randomizedHiddenBiases.append(value)
		}
		
		for _ in 1...outputCount {
			let value = random ? Float.random(in: min...max) : initialValue
			randomizedOutputBiases.append(value)
		}
		
		let weights = [[], randomizedHiddenLayer, randomizedLastLayer]
		let biases = [[], randomizedHiddenBiases, randomizedOutputBiases]
		
		return (weights: weights, biases: biases)
	}
}
