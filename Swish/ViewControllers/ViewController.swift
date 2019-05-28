//
//  ViewController.swift
//  Hoops
//
//  Created by Cazamere Comrie on 1/13/19.
//  Copyright © 2019 Cazamere Comrie. All rights reserved.
//

/*
Basic notes:

 SWISH SHOULD BE A SPECIAL SHOT WHERE YOU DONT HIT THE RIM AND GET WAY MORE POINTS! LIKE DOUBLE?
 Implement distance

 */

import UIKit
import QuartzCore
import ARKit
import Each
import MultipeerConnectivity
class ViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate, ARSessionDelegate {

    @IBOutlet weak var scoreLabel: PaddingLabel!
    @IBOutlet weak var timerLabel: PaddingLabel!
    @IBOutlet weak var planeDetected: UILabel!
    @IBOutlet weak var multiPlayerStatus: UILabel!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var sceneView: ARSCNView!

    var selfHandle: MCPeerID?
    var multipeerSession: MultipeerSession!
    var mapProvider: MCPeerID?
    var isMultiplayer: Bool = false
    var gameTime = Double()
    var gameTimeMin = Int()
    var gameTimeSec = Int()
    var gameTimeMs = Int()
    var gameTimer = Timer()
    
    var basketScene: SCNScene?
    var globalBasketNode: SCNNode?
    let configuration = ARWorldTrackingConfiguration()
    var power: Float = 1
    let timer = Each(0.05).minutes
    var basketAdded: Bool = false
    var receivingForce: SCNVector3?
    var score: Int = 0
    var hostPosition: CodablePosition?
    var playerPosition: CodablePosition?
    var positionAnchor: ARAnchor?
    var playerPositionAnchors: [String : ARAnchor]?
    var cameraTrackingState: ARCamera.TrackingState?
    
    var globalTrackingState: ARCamera.TrackingState?
    var globalCamera: ARCamera?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // start view's AR session
        sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin, ARSCNDebugOptions.showFeaturePoints]
        configuration.planeDetection = .horizontal
        sceneView.autoenablesDefaultLighting = true
        sceneView.session.run(configuration)
        
        // set up multipeer session's data handlers
        multipeerSession.dataHandler = dataHandler
        multipeerSession.basketSyncHandler = basketSyncHandler

        // Set delegates for AR session and AR scene
        sceneView.delegate = self
        sceneView.session.delegate = self

        // taps will set basketball
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(sender:)))
        self.sceneView.addGestureRecognizer(tapGestureRecognizer)
        tapGestureRecognizer.cancelsTouchesInView = false

        // pans will determine angle of basketball
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(sender:)))
        panGestureRecognizer.maximumNumberOfTouches = 1
        panGestureRecognizer.minimumNumberOfTouches = 1
        self.sceneView.addGestureRecognizer(panGestureRecognizer)

        // add timer
        gameTime = 180 // CHANGE GAME TIME AS NEEDED, currently at 3 mins
        gameTimeMin = Int(gameTime) / 60
        gameTimeSec = Int(gameTime) % 60
        gameTimeMs = Int((gameTime * 1000).truncatingRemainder(dividingBy: 1000))
        
        initStyles();
        
        gameTimer = Timer.scheduledTimer(timeInterval: 0.001, target: self, selector: #selector(incrementTimer), userInfo: nil, repeats: true)
        
        sceneView.scene.physicsWorld.contactDelegate = self
        
        basketScene = SCNScene(named: "Bball.scnassets/Basket.scn")
        // Set backboard texture
        basketScene?.rootNode.childNode(withName: "backboard", recursively: true)?.geometry?.firstMaterial?.diffuse.contents = UIImage(named: "backboard.jpg")
        playerPositionAnchors![self.selfHandle!.displayName] = nil
        print(multipeerSession.connectedPeers)
    }
    
    func initStyles(){
        planeDetected.text = "Point your camera towards the floor."
        planeDetected.isHidden = false
        planeDetected.font = planeDetected.font.withSize(28)
        planeDetected.textColor = UIColor.white
        planeDetected.layer.cornerRadius = 2
        planeDetected.textAlignment = .center
        planeDetected.numberOfLines = 0
        planeDetected.shadowColor = UIColor.black
        
        timerLabel.text = String(format: "%02d:%02d:%03d", gameTimeMin, gameTimeSec, gameTimeMs)
        timerLabel.font = timerLabel.font.withSize(24)
        timerLabel.textColor = UIColor.white
        timerLabel?.layer.cornerRadius = 2
        timerLabel.textAlignment = .center
        
        scoreLabel.text = "\(score)"
        scoreLabel.font = scoreLabel.font.withSize(24)
        scoreLabel.textColor = UIColor.white
        scoreLabel?.layer.cornerRadius = 2
        scoreLabel.textAlignment = .center
        
        stopButton?.layer.cornerRadius = 2
    }
    
    @IBAction func endClick(_ sender: Any){
        
    }

    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        if contact.nodeA.physicsBody?.categoryBitMask == CollisionCategory.detectionCategory.rawValue
            || contact.nodeB.physicsBody?.categoryBitMask == CollisionCategory.detectionCategory.rawValue {
            if (contact.nodeB.name! == "detection") {
                self.score+=1
                DispatchQueue.main.async {
                    self.scoreLabel.text = "\(self.score)"
                }
            }
            DispatchQueue.main.async {
                contact.nodeA.removeFromParentNode()
            }
        }
    }


    @objc func incrementTimer(){
        if basketAdded == true {
            gameTime -= 0.001
            gameTimeMin = Int(gameTime) / 60
            gameTimeSec = Int(gameTime) % 60
            gameTimeMs = Int((gameTime * 1000).truncatingRemainder(dividingBy: 1000))
            
            timerLabel.text = String(format: "%02d:%02d:%03d", gameTimeMin, gameTimeSec, gameTimeMs)
            
            if(gameTime <= 0){
                gameTimer.invalidate()
//                if Cache.shared.object(forKey: "SinglePlayerBoard") == nil {
//                    let leaderboardArr:[Int:String] =
//                        [self.score:Cache.shared.object(forKey: "handle") as! String,
//                         -1:"", -1:"", -1:"", -1:"", -1:"", -1:"", -1:""]
//                    Cache.shared.set(leaderboardArr, forKey: "SinglePlayerBoard")
//                } else {
//                    //let leaderboardArr = Cache.shared.object(forKey: "SinglePlayerBoard")
//                    //for (index, keyValue) in leaderboardArr.enumerated() {
//
//                    //}
//
//                }
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        sceneView.session.pause()
    }

    func shootBall(velocity: CGPoint, translation: CGPoint) {
        guard let pointOfView = self.sceneView.pointOfView else {return}
        self.removeEveryOtherBall()
        let transform = pointOfView.transform
        let location = SCNVector3(transform.m41, transform.m42, transform.m43)
        let orientation = SCNVector3(-transform.m31, -transform.m32, -transform.m33)
        let position = location + orientation

        // add the ball
        let ball = SCNNode(geometry: SCNSphere(radius: 0.25))
        ball.geometry?.firstMaterial?.diffuse.contents = UIImage(named: "ballTexture.png") // Set ball texture
        ball.position = position
        
        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: ball))
        ball.physicsBody = body
        ball.name = "Basketball"
        body.restitution = 0.2

        let xForce = translation.x > 0 ? min(1.5, Float(translation.x)/100) : max(-1.5, Float(translation.x)/100)
        let yForce = min(10, Float(translation.y) / -300 * 8)
        let zForce = max(-3, Float(velocity.y) / 900)
        ball.physicsBody?.applyForce(SCNVector3(xForce, yForce, zForce), asImpulse: true)
        ball.physicsBody?.categoryBitMask = CollisionCategory.ballCategory.rawValue
        ball.physicsBody?.collisionBitMask = CollisionCategory.detectionCategory.rawValue

//        let basketPosition = globalBasketNode!.position
//        let playerPosition = CodablePosition(dim1: position.x, dim2: position.y, dim3: position.z, dim4: 0)
//        let codableBasketPosition = CodablePosition(dim1: basketPosition.x, dim2: basketPosition.y, dim3: basketPosition.z, dim4: 0)
//        let codableBall = CodableBall(forceX: xForce, forceY: yForce, forceZ: zForce, playerPosition: playerPosition, basketPosition: codableBasketPosition)
//        //print("PlayerPosition = \(self.playerPosition?.dim1), \(self.playerPosition?.dim2), \(self.playerPosition?.dim3)\nBasketPosition = \(globalBasketNode!.position)")
//        self.sceneView.scene.rootNode.addChildNode(ball) // create another ball after you shoot
//        print("Ballsarehuge: \(ball.position)")
//        do {
//            let data : Data = try JSONEncoder().encode(codableBall)
//            self.multipeerSession.sendToAllPeers(data)
//        } catch {
//
//        }
        
        guard let positionTransform = sceneView.pointOfView?.simdWorldTransform else { return }
        guard self.isMultiplayer else {return}
        
        let anchorName = self.selfHandle?.displayName
        if(positionAnchor != nil){
            sceneView.session.remove(anchor: positionAnchor!)
        }
        positionAnchor = ARAnchor(name: anchorName!, transform: positionTransform)
        sceneView.session.add(anchor: positionAnchor!)
        let codableCol1 = CodablePosition(dim1: positionTransform.columns.0.x, dim2: positionTransform.columns.0.y, dim3: positionTransform.columns.0.z, dim4: positionTransform.columns.0.w)
        let codableCol2 = CodablePosition(dim1: positionTransform.columns.1.x, dim2: positionTransform.columns.1.y, dim3: positionTransform.columns.1.z, dim4: positionTransform.columns.1.w)
        let codableCol3 = CodablePosition(dim1: positionTransform.columns.2.x, dim2: positionTransform.columns.2.y, dim3: positionTransform.columns.2.z, dim4: positionTransform.columns.2.w)
        let codableCol4 = CodablePosition(dim1: positionTransform.columns.3.x, dim2: positionTransform.columns.3.y, dim3: positionTransform.columns.3.z, dim4: positionTransform.columns.3.w)
        let encodableTransform = CodableTransform(c1: codableCol1, c2: codableCol2, c3: codableCol3, c4: codableCol4, s: anchorName!, fX: xForce, fY: yForce, fZ: zForce)
        do{
            let data : Data = try JSONEncoder().encode(encodableTransform)
            self.multipeerSession.sendToAllPeers(data)
        }
        catch{
            print("Was not able to encode transform to data")
        }
        

        // collision detection
        let detection = SCNNode(geometry: SCNCylinder(radius: 0.3, height: 0.2))
        let body2 = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: detection))
        detection.physicsBody = body2
        detection.opacity = 0.0

        detection.position = SCNVector3(-0.4, 0.35, -3.5) // TODO: determine relative position of cylinder

        detection.name = "detection"
       // detection.isHidden = true
        detection.physicsBody?.categoryBitMask = CollisionCategory.detectionCategory.rawValue
        detection.physicsBody?.contactTestBitMask = CollisionCategory.ballCategory.rawValue
        self.sceneView.scene.rootNode.addChildNode(detection)
    } // create and shoot ball

    @objc func handlePan(sender: UIPanGestureRecognizer){
        guard let sceneView = sender.view as? ARSCNView else {return}

        if (basketAdded && sender.state == .ended)
        {
            let velocity = sender.velocity(in: sceneView)
            let translation = sender.translation(in: sceneView)
            shootBall(velocity: velocity, translation : translation)
        }
    }

    @objc func handleTap(sender: UITapGestureRecognizer) {
        guard let sceneView = sender.view as? ARSCNView else {return}
        let touchLocation = sender.location(in: sceneView)
        let hitTestResult = sceneView.hitTest(touchLocation, types: [.existingPlaneUsingExtent])
        if !hitTestResult.isEmpty {
            if(!basketAdded){
                self.addBasket(hitTestResult: hitTestResult.first!)
                if(Globals.instance.isHosting){
                    getAndSendWorldCoordinates(hitTestResult: hitTestResult.first!)
                }
            }
            else if(basketAdded && Globals.instance.isHosting){
                // only send worldcoordinates if we're the host
            }
            else if(basketAdded && !Globals.instance.isHosting){
                // if basket has been added and we're not hosting, host has pressed position first
                // need to sync game worlds
                addBasket(hitTestResult: hitTestResult.first!)
                
            }
        }
    }
    
    func getAndSendWorldCoordinates(hitTestResult: ARHitTestResult){
        do{
            let tapPosition = hitTestResult.worldTransform.columns.3
            print(tapPosition)
            let encodablePosition = CodablePosition(dim1: tapPosition.x, dim2: tapPosition.y, dim3: tapPosition.z, dim4: tapPosition.w)
            let data : Data = try JSONEncoder().encode(encodablePosition)
            multipeerSession.sendToAllPeers(data)
        }
        catch{
            print("Was not able to encode position to data")
        }
    }

    //func addDetection()

    func addBasket(hitTestResult: ARHitTestResult) {
        if basketAdded == false {

            // Set backboard texture
            basketScene?.rootNode.childNode(withName: "backboard", recursively: true)?.geometry?.firstMaterial?.diffuse.contents = UIImage(named: "backboard.jpg")
            
            basketScene?.rootNode.childNode(withName: "pole", recursively: true)?.geometry?.firstMaterial?.diffuse.contents = UIColor.gray

            let basketNode = basketScene?.rootNode.childNode(withName: "ball", recursively: false)
            let positionOfPlane = hitTestResult.worldTransform.columns.3
            let xPosition = positionOfPlane.x
            let yPosition = positionOfPlane.y
            let zPosition = positionOfPlane.z
            basketNode?.position = SCNVector3(xPosition,yPosition,zPosition)

            basketNode?.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: basketNode!, options: [SCNPhysicsShape.Option.keepAsCompound: true, SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron]))
            let anchor = ARAnchor(name: "basketAnchor", transform: hitTestResult.worldTransform)
            sceneView.session.add(anchor: anchor)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.basketAdded = true
            }
        }
    } // adds backboard and hoop to the scene view
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        if(anchor.name == "basketAnchor" && !basketAdded){
            let basketNode = basketScene!.rootNode.childNode(withName: "ball", recursively: false)
            let positionOfPlane = anchor.transform.columns.3
            print("BASKET POSITION \(positionOfPlane)")
            basketNode!.position = SCNVector3(positionOfPlane.x, positionOfPlane.y, positionOfPlane.z)
            basketNode?.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: basketNode!, options: [SCNPhysicsShape.Option.keepAsCompound: true, SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron]))
            basketAdded = true
            return basketNode
        }
        else{
            return nil
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func shareSession(_ button: UIButton) {
        guard Globals.instance.isHosting else{ return }

        var isNormal = true
        switch(globalTrackingState!){
        case .normal:
            isNormal = true
        default:
            isNormal = false
        }
        
        while(isNormal == false) {
            globalTrackingState = globalCamera!.trackingState
            switch(globalTrackingState!){
            case .normal:
                isNormal = true
            default:
                isNormal = false
            }
        }
        sceneView.session.getCurrentWorldMap { worldMap, error in
            guard let map = worldMap
                else { print("Error: \(error!.localizedDescription)"); return }
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                else { fatalError("can't encode map") }
            self.multipeerSession.sendToAllPeers(data)
        }
    }
    
    func basketSyncHandler(worldMap: ARWorldMap, peerID: MCPeerID){
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        configuration.initialWorldMap = worldMap
        
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
//        for anchor in worldMap.anchors{
//            if (anchor.name == "basketAnchor"){
//                if(basketAdded == false){
//                    sceneView.session.add(anchor: anchor)
//                }
//            }
//        }
        
        // Remember who provided the map for showing UI feedback.
        mapProvider = peerID
    }

    func dataHandler(_ data: Data, from peer: MCPeerID) {
        // get the ball from other player and add it to scene
        if let force : Float = data.withUnsafeBytes({ $0.pointee }){
            power = force
            print("got the force")
        }
        
        do{
            // if the data is a position, we need to sync our game world's position with that position
            let decodedData = try JSONDecoder().decode(CodablePosition.self, from: data)
            self.hostPosition = decodedData
        }
        catch{
        }
        
        do{
            // if the data is a position, we need to sync our game world's position with that position
            let decodedData = try JSONDecoder().decode(CodableTransform.self, from: data)
            
//            guard let pointOfView = self.sceneView.pointOfView else {return}
//            let transform = pointOfView.transform
//            let location = SCNVector3(transform.m41, transform.m42, transform.m43)
//            let orientation = SCNVector3(-transform.m31, -transform.m32, -transform.m33)
//            let position = location + orientation
//
//            let basketPosition = globalBasketNode!.position
//            let diffX = basketPosition.x - decodedData.basketPosition.dim1
//            let diffY = basketPosition.y - decodedData.basketPosition.dim2
//            let diffZ = basketPosition.z - decodedData.basketPosition.dim3
            
            let col0 = simd_float4(decodedData.col1.dim1, decodedData.col1.dim2, decodedData.col1.dim3, decodedData.col1.dim4)
            let col1 = simd_float4(decodedData.col2.dim1, decodedData.col2.dim2, decodedData.col2.dim3, decodedData.col2.dim4)
            let col2 = simd_float4(decodedData.col3.dim1, decodedData.col3.dim2, decodedData.col3.dim3, decodedData.col3.dim4)
            let col3 = simd_float4(decodedData.col4.dim1, decodedData.col4.dim2, decodedData.col4.dim3, decodedData.col4.dim4)
            
            let tform = simd_float4x4(col0, col1, col2, col3)
            let anchor = ARAnchor(name: decodedData.playerID, transform: tform)
            
            if(!playerPositionAnchors!.isEmpty){
                if(playerPositionAnchors![decodedData.playerID] != nil){
                    sceneView.session.remove(anchor: playerPositionAnchors![decodedData.playerID]!)  // remove existing anchor from sceneview
                }
            }
            
            playerPositionAnchors![decodedData.playerID] = anchor
            let position = anchor.transform.columns.3
            let ball = SCNNode(geometry: SCNSphere(radius: 0.25))
            ball.geometry?.firstMaterial?.diffuse.contents = UIImage(named: "ballTexture.png") // Set ball texture
            //ball.position = SCNVector3(decodedData.playerPosition.dim1 + basketPosition.x, decodedData.playerPosition.dim2 + basketPosition.y, decodedData.playerPosition.dim3 + basketPosition.z)
            ball.position = SCNVector3(position.x, position.y, position.z)
            print(ball.position)
            //print(ball.position)
            let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: ball))
            ball.physicsBody = body
            ball.name = "Basketball"
            body.restitution = 0.2
            
            let xForce = decodedData.forceX
            let yForce = decodedData.forceY
            let zForce = decodedData.forceZ
            ball.physicsBody?.applyForce(SCNVector3(xForce, yForce, zForce), asImpulse: true)
            ball.physicsBody?.categoryBitMask = CollisionCategory.ballCategory.rawValue
            ball.physicsBody?.collisionBitMask = CollisionCategory.detectionCategory.rawValue
            self.sceneView.scene.rootNode.addChildNode(ball) // add ball to scene
        }
        catch{
        }
    }
    

    // called from ARSCNViewDelegate
    // SCNNode relating to a new anchor was added to the scene
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {

        if(anchor is ARPlaneAnchor){
            DispatchQueue.main.async {
                self.planeDetected.isHidden = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.planeDetected.isHidden = true
            }
        }
        else if(anchor.name == "basketAnchor"){
            globalBasketNode = node
        }
    } // just to deal with planeDetected button on top. +2 to indicate button is there for 2 seconds and then disappears
    
    // called every frame
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
    }

    // called when the state of the camera is changed
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        globalTrackingState = camera.trackingState
        globalCamera = camera
        updateMultiPlayerStatus(for: session.currentFrame!, trackingState: camera.trackingState)
    }

    // called when AR session fails
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user.
        multiPlayerStatus.text = "Session failed: \(error.localizedDescription)"
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame){

    }

    private func updateMultiPlayerStatus(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
        // Update the UI to provide feedback on the state of the AR experience.
        let message: String

        switch trackingState {
        case .normal where frame.anchors.isEmpty && multipeerSession.connectedPeers.isEmpty:
            // No planes detected; provide instructions for this app's AR interactions.
            message = "Move around to map the environment, or wait to join a shared session."

        case .normal where !multipeerSession.connectedPeers.isEmpty && mapProvider == nil:
            let peerNames = multipeerSession.connectedPeers.map({ $0.displayName }).joined(separator: ", ")
            message = "Connected with \(peerNames)."

        case .notAvailable:
            message = "Tracking unavailable."

        case .limited(.excessiveMotion):
            message = "Tracking limited - Move the device more slowly."

        case .limited(.insufficientFeatures):
            message = "Tracking limited - Point the device at an area with visible surface detail, or improve lighting conditions."

        case .limited(.initializing) where mapProvider != nil,
             .limited(.relocalizing) where mapProvider != nil:
            message = "Received map from \(mapProvider!.displayName)."

        case .limited(.relocalizing):
            message = "Resuming session — move to where you were when the session was interrupted."

        case .limited(.initializing):
            message = "Initializing AR session."

        default:
            // No feedback needed when tracking is normal and planes are visible.
            // (Nor when in unreachable limited-tracking states.)
            message = ""

        }

        multiPlayerStatus.text = message
        multiPlayerStatus.isHidden = message.isEmpty
    }

    

    func removeEveryOtherBall() {
        self.sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
            if node.name == "Basketball" {
                node.removeFromParentNode()
            }
        }
    } // remove the balls yooo

    deinit {
        self.timer.stop()
    }
}

struct CollisionCategory: OptionSet {
    let rawValue: Int
    static let ballCategory  = CollisionCategory(rawValue: 1 << 0)
    static let detectionCategory = CollisionCategory(rawValue: 1 << 1)
}

func +(left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x + right.x, left.y + right.y, left.z + right.z)
} // useful operator to add 3D vectors
