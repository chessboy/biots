//
//  CellComponent.swift
//  BioGenesis
//
//  Created by Robert Silverman on 4/12/20.
//  Copyright © 2020 Rob Silverman. All rights reserved.
//

import SpriteKit
import GameplayKit
import OctopusKit

final class CellComponent: OKComponent, OKUpdatableComponent {
    			
	var genome: Genome
	var expired = false
	
	var energy: CGFloat
	var stamina: CGFloat = 1
	
	var age: CGFloat = 0
	var lastSpawnedAge: CGFloat = 0
	var lastPregnantAge: CGFloat = 0
	var lastInteractedAge: CGFloat = 0
	var lastBlinkAge: CGFloat = 0
	
	var spawnCount: Int = 0
	var isInteracting = false
	var matedCount = 0

	var healthNode: SKShapeNode!
	var speedNode: SKShapeNode!
	var eyeNodes: [SKShapeNode] = []
	
	var matingGenome: Genome?

	var isPregnant: Bool {
		return matingGenome != nil
	}
	
	var canInteract: Bool {
		return !expired && age > Constants.Cell.matureAge && age - lastInteractedAge > Constants.Cell.interactionAge
	}

	var canMate: Bool {
		return !expired && age > Constants.Cell.matureAge && !isPregnant && health > Constants.Cell.mateHealth
	}
	
	var maximumEnergy: CGFloat {
		return isPregnant ? Constants.Cell.maximumEnergy * 2 : Constants.Cell.maximumEnergy
	}

	var health: CGFloat {
		let energyRatio = energy/maximumEnergy
		return energyRatio - (1-stamina)
	}
	
	var visibility: CGFloat {
		let lastBlinkDelta = (age - lastBlinkAge).clamped(0, Constants.Cell.blinkAge)
		let visibility = (1 - (lastBlinkDelta / Constants.Cell.blinkAge))
//		print("age: \(age.formattedTo2Places), lastBlinkAge: \(lastBlinkAge.formattedTo2Places), lastBlinkDelta: \(lastBlinkDelta.formattedTo2Places), visibility: \(visibility.formattedTo2Places)")
		return visibility
	}
	
	var effectiveVisibility: CGFloat {
		let actualVisibility = visibility
		return actualVisibility > 0.5 ? 1 : actualVisibility
	}
	
	var frame = Int.random(100)

	init(genome: Genome, initialEnergy: CGFloat) {
		self.genome = genome
		self.energy = initialEnergy
		super.init()
	}

	func startInteracting() {
		isInteracting = true
		lastInteractedAge = age
	}
	
	func stopInteracting() {
		isInteracting = false
	}

	required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var requiredComponents: [GKComponent.Type]? {[
		SpriteKitComponent.self,
		PhysicsComponent.self,
		ContactComponent.self,
		VisionComponent.self,
		NeuralNetComponent.self,
		BrainComponent.self
	]}
	
	override func didAddToEntity() {
		if let node = entityNode as? SKShapeNode {
			node.setScale(0.2)
			node.run(SKAction.scale(to: 1, duration: 10))
		}
	}
    	
	func incurEnergyChange(_ delta: CGFloat, showEffect: Bool = false) {
		energy += delta
		energy = energy.clamped(to: 0...maximumEnergy)
		if showEffect {
			updateHealthNode()
			contactEffect(impact: delta)
		}
	}
	
	func incurStaminaChange(_ delta: CGFloat, showEffect: Bool = false) {
		stamina -= delta
		stamina = stamina.clamped(to: 0...1)
		if showEffect {
			updateHealthNode()
			contactEffect(impact: delta)
		}
	}
		
	func kill() {
		energy = 0
		stamina = 0
	}
	
	func cellAndAlgaeCollided(algae: AlgaeComponent) {
				
		let bite: CGFloat = Constants.Algae.bite
		guard energy + bite/4 < maximumEnergy else { return }
		
		incurEnergyChange(bite, showEffect: true)

		algae.energy -= bite
		if algae.energy < bite {
			algae.energy = 0
		}
		algae.bitten()
	}

	struct BodyContact {
		var when: TimeInterval
		var body: SKPhysicsBody
		
		mutating func updateWhen(when: TimeInterval) {
			self.when = when
		}
	}
	
	var contactedAlgaeComponents: [BodyContact] = []
	var onTopOfFood = false
	
	func checkAlgaeContacts() {
		let now = Date().timeIntervalSince1970

		if frame.isMultiple(of: 30) {
			//let count = contactedAlgaeComponents.count
			contactedAlgaeComponents = contactedAlgaeComponents.filter({ now - $0.when <= Constants.Cell.timeBetweenBites })
			//print("body purge: old count: \(count), new count: \(contactedAlgaeComponents.count)")
		}
		
		onTopOfFood = false
		if let scene = OctopusKit.shared.currentScene, let bodies = entityNode?.physicsBody?.allContactedBodies(), bodies.count > 0 {
			for body in bodies {
				
				if body.categoryBitMask == Constants.CategoryBitMasks.algae {
					if let algae = scene.entities.filter({ $0.component(ofType: PhysicsComponent.self)?.physicsBody == body }).first?.component(ofType: AlgaeComponent.self), algae.energy > 0 {

						onTopOfFood = true
						var contact = contactedAlgaeComponents.filter({ $0.body == body }).first
						
						if contact == nil {
							//print("added at \(now), ate algae energy: \(algae.energy.formattedTo2Places)")
							contactedAlgaeComponents.append(BodyContact(when: now, body: body))
							cellAndAlgaeCollided(algae: algae)
						} else if now - contact!.when > Constants.Cell.timeBetweenBites {
							//print("found at: \(contact!.when), now: \(now), delta: \(now - contact!.when), ate algae energy: \(algae.energy.formattedTo2Places)")
							contact!.updateWhen(when: now)
							cellAndAlgaeCollided(algae: algae)
						}
					}
				}
			}
		}
	}
	
	
	func blink() {
		
		guard age - lastBlinkAge > 30 else { return }
		
		lastBlinkAge = age
		incurEnergyChange(-Constants.Cell.blinkExertion)
		eyeNodes.forEach({ eyeNode in
			eyeNode.fillColor = .black
			eyeNode.strokeColor = .white
			eyeNode.run(SKAction.bulge(xScale: 0.05, yScale: 0.85, scalingDuration: 0.075, revertDuration: 0.125)) {
				eyeNode.yScale = 0.85
			}
		})
	}
	
    override func update(deltaTime seconds: TimeInterval) {
		
		guard !expired else { return }
		age += 1
				
		checkAlgaeContacts()
		showStats()
		
		// check old age or malnutrition
		if age >= Constants.Cell.oldAge || health <= 0 {
			expire()
		}
		
		// update visual indicators
		updateHealthNode()
		updateSpeedNode()

		if Constants.Environment.selfReplication, frame.isMultiple(of: 10) {
			if !isPregnant, canMate, spawnCount < 5, age - lastSpawnedAge > Constants.Cell.gestationAge, genome.generation <= Constants.Environment.generationTrainingThreshold, age > Constants.Cell.selfReplicationAge {
				mated(otherGenome: genome)
			}
		}
		
		// check spawning
		if isPregnant, age - lastPregnantAge > Constants.Cell.gestationAge, health >= Constants.Cell.spawnHealth {
			spawnChildren()
			lastSpawnedAge = age
		}

		frame += 1
    }
	
	func expire() {
		if let scene = OctopusKit.shared.currentScene, let entity = self.entity, let node = entityNode {
			expired = true
			node.run(.group([.fadeOut(withDuration: 0.2), SKAction.scale(to: 0.1, duration: 0.2)])) {
				scene.removeEntityOnNextUpdate(entity)
				
				if node.position.distance(to: .zero) < Constants.Environment.worldRadius * 0.5, let fountainComponent = self.coComponent(ResourceFountainComponent.self) {
					let algae = fountainComponent.createAlgaeEntity(energy: Constants.Algae.bite * 5)
					if let algaeComponent = algae.component(ofType: AlgaeComponent.self) {
						if let algaeNode = algaeComponent.coComponent(ofType: SpriteKitComponent.self)?.node, let physicsBody = algaeNode.physicsBody {
							algaeNode.position = node.position
							physicsBody.velocity = node.physicsBody?.velocity ?? .zero
							physicsBody.angularVelocity = node.physicsBody?.angularVelocity ?? .zero
							scene.addEntity(algae)
						}
					}
				}
			}
		}
	}

	func updateHealthNode() {

		guard frame.isMultiple(of: 5) else { return }
		
		let showingHealth = !healthNode.isHidden
		let showHealth = coComponent(GlobalDataComponent.self)?.showCellHealth ?? false
		
		if !showingHealth, showHealth {
			healthNode.alpha = 0
			healthNode.isHidden = false
			healthNode.run(.fadeIn(withDuration: 0.2))
		}
		else if showingHealth, !showHealth {
			healthNode.run(.fadeOut(withDuration: 0.1)) {
				self.healthNode.isHidden = true
				self.healthNode.alpha = 0
			}
		}

		if showHealth {
			let intenstity = health
			healthNode.fillColor = SKColor(red: 1 - intenstity, green: intenstity, blue: 0, alpha: 1)
		}
	}
	
	func updateSpeedNode() {
		
		guard Constants.Cell.showSpeed, frame.isMultiple(of: 2) else { return }
		
		let showingSpeed = !speedNode.isHidden
		let showSpeed = coComponent(GlobalDataComponent.self)?.showCellHealth ?? false
		
		if !showingSpeed, showSpeed {
			speedNode.alpha = 0
			speedNode.isHidden = false
		}
		else if showingSpeed, !showSpeed {
			speedNode.run(.fadeOut(withDuration: 0.1)) {
				self.speedNode.isHidden = true
				self.speedNode.alpha = 0
			}
		}

		if showSpeed, let speedBoost = coComponent(BrainComponent.self)?.inference.speedBoost.average {
			speedNode.alpha = speedBoost.cgFloat
		}
	}
	
	func showStats() {
		
		if  let statsNode = coComponent(EntityStatsComponent.self)?.statsNode {
			
			if frame.isMultiple(of: 10) {
				if coComponent(GlobalDataComponent.self)?.showCellStats == true {
					
					if let cameraScale = OctopusKit.shared.currentScene?.camera?.xScale {
						let scale = (0.2 * cameraScale).clamped(0.3, 0.75)
						if statsNode.xScale != scale {
							statsNode.run(SKAction.scale(to: scale, duration: 0.2))
						}
					}
					
//					let position = entityNode?.position ?? .zero
//					let angle = ((entityNode?.zRotation ?? .zero) + π).normalizedAngle
//					let theta = atan2(position.y, position.x).normalizedAngle
//					let angleToCenter = ((theta + angle + π).normalizedAngle / (2*π))
					
					let healthFormatted = health.formattedToPercentNoDecimal
					let energyFormatted = (energy/maximumEnergy).formattedToPercentNoDecimal
					let staminaFormatted = stamina.formattedToPercentNoDecimal
					var thrustDescr = "-none-"
					var speedBoostDescr = "-none-"

					if let inference = coComponent(BrainComponent.self)?.inference {
						thrustDescr = inference.thrust.average.description
						speedBoostDescr = inference.speedBoost.average.formattedTo2Places
					}
					
					statsNode.setLineOfText("h: \(healthFormatted), e: \(energyFormatted), s: \(staminaFormatted), v: \(visibility.formattedToPercentNoDecimal), ev: \(effectiveVisibility.formattedToPercentNoDecimal)", for: .line1)
					statsNode.setLineOfText("gen: \(genome.generation) | mkrs: \(genome.marker1 ? "1" : "0")|\(genome.marker2 ? "1" : "0") | age: \((age/Constants.Cell.oldAge).formattedToPercentNoDecimal)", for: .line2)
					statsNode.setLineOfText("spw: \(spawnCount), mat: \(matedCount) | thr: \(thrustDescr) | spdB: \(speedBoostDescr)", for: .line3)
					statsNode.updateBackgroundNode()
				}
			}
			if let node = entityNode {
				statsNode.zRotation = 2*π - node.zRotation
			}
		}
	}

	func spawnChildren(selfReplication: Bool = false) {
		guard let node = entityNode as? SKShapeNode, let scene = OctopusKit.shared.currentScene, let matingGenome = matingGenome else {
			return
		}

		if let worldScene = scene as? WorldScene, let worldComponent = worldScene.entity?.component(ofType: WorldComponent.self), worldComponent.currentCells.count >= Constants.Environment.maximumCells {
			self.matingGenome = nil
			self.lastPregnantAge = 0
			node.run(SKAction.scale(to: 1, duration: 0.25))
			return
		}
		
		energy = energy / 4
		incurStaminaChange(0.1)
		
		spawnCount += 1
		
		let selfReplicationSpawn = [(genome, -π/8), (genome, π/8)]
		let standardSpawn =  [(genome, -π/8), (matingGenome, π/8)]

		let spawn = selfReplication ? selfReplicationSpawn : standardSpawn
		
		for (parentGenome, angle) in spawn {
			
			let position = node.position - CGPoint(angle: node.zRotation + angle) * Constants.Cell.radius * 2
			let clonedGenome = Genome(parent: parentGenome)
			let childCell = CellComponent.createCell(genome: clonedGenome, at: position, initialEnergy: Constants.Cell.initialEnergy, fountainComponent: RelayComponent(for: coComponent(ResourceFountainComponent.self)))
			childCell.node?.zRotation = node.zRotation + angle + π
			
			if coComponent(GlobalDataComponent.self)?.showCellStats ?? false {
				childCell.addComponent(EntityStatsComponent())
			}
			if coComponent(GlobalDataComponent.self)?.showCellEyeSpots ?? false {
				childCell.addComponent(EyesComponent())
			}
			//print("\(currentColor)-🥚 id: \(clonedGenome.id), gen: \(clonedGenome.generation)")
			//print(clonedGenome.jsonString)
			
			scene.run(SKAction.wait(forDuration: 0.1)) {
				scene.addEntity(childCell)
				
				if let hideNode = OctopusKit.shared.currentScene?.gameCoordinator?.entity.component(ofType: GlobalDataComponent.self)?.hideAlgae {
					childCell.node?.isHidden = hideNode
				}
			}
		}
		
		self.matingGenome = nil
		node.run(SKAction.scale(to: 1, duration: 0.25))
	}
	
	func mated(otherGenome: Genome) {
		guard !isPregnant else {
			return
		}
		
		matingGenome = otherGenome
		lastPregnantAge = age
		
		if let node = entityNode as? SKShapeNode {
			node.run(SKAction.scale(to: 1.33, duration: 0.25))
		}
	}
	
	func contactEffect(impact: CGFloat) {
		
		guard !healthNode.isHidden else {
			return
		}
		
		if impact > 0 {
			let pulseUp = SKAction.scale(to: 1.5, duration: 0.2)
			let pulseDown = SKAction.scale(to: 1, duration: 0.4)
			let sequence = SKAction.sequence([pulseUp, .wait(forDuration: 0.1), pulseDown])
			sequence.timingMode = .easeInEaseOut
			healthNode.run(sequence)
		} else {
			let pulseDown = SKAction.scale(to: 0.5, duration: 0.1)
			let pulseUp = SKAction.scale(to: 1, duration: 0.2)
			let sequence = SKAction.sequence([pulseDown, .wait(forDuration: 0.1), pulseUp])
			sequence.timingMode = .easeInEaseOut
			healthNode.run(sequence)
		}
	}
}

extension CellComponent {
		
	static func createCell(genome: Genome, at position: CGPoint, initialEnergy: CGFloat = Constants.Cell.initialEnergy, fountainComponent: RelayComponent<ResourceFountainComponent>) -> OKEntity {

		let radius = Constants.Cell.radius
		let node = SKShapeNode(circleOfRadius: radius)
		node.name = "cell"
		node.fillColor = SKColor.lightGray
		node.lineWidth = 0
		node.position = position
		node.zPosition = Constants.ZeeOrder.cell
		node.zRotation = CGFloat.randomAngle
		node.blendMode = .replace
		node.isAntialiased = false
		
//		let visorNode = SKShapeNode()
//		let visorPath = CGMutablePath()
//		visorPath.addArc(center: .zero, radius: radius * 0.7, startAngle: π + π/4 + π/8, endAngle: π - π/4 - π/8, clockwise: true)
//		visorNode.path = visorPath
//		visorNode.fillColor = .clear
//		visorNode.lineWidth = radius * 0.15
//		visorNode.zRotation = π
//
//		visorNode.lineCap = .round
//		visorNode.strokeColor = .black
//		visorNode.isAntialiased = false
//		visorNode.zPosition = Constants.ZeeOrder.cell + 0.1
//		node.addChild(visorNode)
		
		var eyeNodes: [SKShapeNode] = []
		for angle in [-π/4.5, π/4.5] {
			let eyeNode = SKShapeNode(circleOfRadius: radius * 0.2)
			eyeNode.fillColor = .black
			eyeNode.strokeColor = .lightGray
			eyeNode.yScale = 0.75
			eyeNode.lineWidth = Constants.Cell.radius * 0.1
			eyeNode.position = CGPoint(angle: angle) * radius * 0.65
			node.addChild(eyeNode)
			eyeNode.zPosition = node.zPosition + 0.2
			eyeNodes.append(eyeNode)
		}
		
		let healthNode = SKShapeNode(circleOfRadius: radius * 0.3)
		healthNode.fillColor = .darkGray
		healthNode.lineWidth = radius * 0.05
		healthNode.strokeColor = Constants.Colors.background
		healthNode.isAntialiased = false
		healthNode.isHidden = true
		healthNode.zPosition = Constants.ZeeOrder.cell + 0.1
		node.addChild(healthNode)
		
		let speedNode = SKShapeNode()
		let speedPath = CGMutablePath()
		speedPath.addArc(center: .zero, radius: radius * 0.7, startAngle: π/4 + π/8, endAngle: -π/4 - π/8, clockwise: true)
		speedNode.path = speedPath
		speedNode.fillColor = .clear
		speedNode.lineWidth = radius * 0.15
		speedNode.isHidden = true
		speedNode.zRotation = π
		
		speedNode.lineCap = .round
		speedNode.strokeColor = .white
		speedNode.isAntialiased = false
		speedNode.zPosition = Constants.ZeeOrder.cell + 0.1
		node.addChild(speedNode)

		let physicsBody = SKPhysicsBody(circleOfRadius: radius)
		physicsBody.categoryBitMask = Constants.CategoryBitMasks.cell
		physicsBody.collisionBitMask = Constants.CollisionBitMasks.cell
		physicsBody.contactTestBitMask = Constants.ContactBitMasks.cell
		physicsBody.allowsRotation = false
		physicsBody.usesPreciseCollisionDetection = true
		physicsBody.mass = 5
		
		physicsBody.linearDamping = 1
		physicsBody.friction = 1
		
		let range = SKRange(lowerLimit: 0, upperLimit: Constants.Environment.worldRadius)
		let keepInBounds = SKConstraint.distance(range, to: .zero)
		node.constraints = [keepInBounds]

		let cellComponent = CellComponent(genome: genome, initialEnergy: initialEnergy)
		cellComponent.healthNode = healthNode
		cellComponent.speedNode = speedNode
		cellComponent.eyeNodes = eyeNodes

		return OKEntity(components: [
			SpriteKitComponent(node: node),
			PhysicsComponent(physicsBody: physicsBody),
			RelayComponent(for: OctopusKit.shared.currentScene?.sharedPhysicsEventComponent),
			RelayComponent(for: OctopusKit.shared.currentScene?.sharedPointerEventComponent),
			RelayComponent(for: OctopusKit.shared.currentScene?.gameCoordinator?.entity.component(ofType: GlobalDataComponent.self)),
			fountainComponent,
			VisionComponent(),
			NeuralNetComponent(genome: genome),
			BrainComponent(),
			ContactComponent(),
			cellComponent
		])
	}
}
