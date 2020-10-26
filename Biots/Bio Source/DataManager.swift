//
//  DataManager.swift
//  Biots
//
//  Created by Robert Silverman on 10/24/20.
//  Copyright © 2020 Rob Silverman. All rights reserved.
//

import Foundation
import OctopusKit

class DataManager {
	static let shared = DataManager()
	
	static let keyCreatedLocalDocuments = "createdLocalDocuments"
	static let bundledFileConfigFilename = "bundled-file-configs"

	var gameState: GameState?
	
	init() {
		checkLocalDocuments()
		
		if let gameState: GameState = LocalFileManager.shared.loadDataFile(Constants.Env.saveSavedStateFilename, treatAsWarning: true) {
			self.gameState = gameState
			OctopusKit.logForSimInfo.add("loaded save state: \(gameState.description)")
		}
		else if let gameState: GameState = LocalFileManager.shared.loadDataFile(Constants.Env.firstRunSavedStateFilename) {
			self.gameState = gameState
			OctopusKit.logForSimInfo.add("loaded save state: \(gameState.description)")
		} else {
			OctopusKit.logForSimErrors.add("could not load a save state")
		}
	}
	
	func checkLocalDocuments() {
		let defaults = UserDefaults.standard

		if !defaults.bool(forKey: DataManager.keyCreatedLocalDocuments) {
			
			if let bundledFileConfigs: [BundledFileConfig] = loadJsonFromFile(DataManager.bundledFileConfigFilename) {
				
				for config in bundledFileConfigs {
					if let worldObjects: [WorldObject] = loadJsonFromFile(config.worldObjectsFilename), let genomes: [Genome] = loadJsonFromFile(config.genomeFilename) {
						let gameState = GameState(difficultyMode: config.difficultyMode, algaeTarget: config.algaeTarget, worldObjects: worldObjects, genomes: genomes)
						LocalFileManager.shared.saveGameStateToFile(gameState: gameState, filename: config.filename)
					}
				}
				
				defaults.set(true, forKey: DataManager.keyCreatedLocalDocuments)
			}
		}
	}
}
