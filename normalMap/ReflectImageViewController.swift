//
//  reflectImageViewController.swift
//  normalMap
//
//  Created by Tony on 2025/4/16.
//

import UIKit
import MetalKit
import CoreMotion
import SpriteKit

class ReflectImageViewController: UIViewController {
    public var orginImage: UIImage?
    public var normalMappingImage: UIImage?

    private let motionManager = CMMotionManager()

    private var sceneView: SKView!
    
    private var lightNode:SKLightNode?
    
    private var spriteNode:SKSpriteNode?
    
    private var scene:SKScene?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .white

        // 创建 SpriteKit 场景视图
        sceneView = SKView(frame: self.view.bounds)
        self.view.addSubview(sceneView)

        // 创建场景
        let scene = SKScene(size: self.view.bounds.size)
        self.scene = scene
        scene.backgroundColor = .clear

        // 使用原图和法线贴图
        if let orginImage = self.orginImage, let normalMappingImage = self.normalMappingImage {
            let texture = SKTexture(image: orginImage)
            let normalTexture = SKTexture(image: normalMappingImage)

            let spriteNode = SKSpriteNode(texture: texture, normalMap: normalTexture)
            self.spriteNode = spriteNode
            var width = orginImage.size.width
            var height = orginImage.size.height
            if width > self.view.bounds.width {
            width = self.view.bounds.width
            height = height * width / orginImage.size.width
            }
            spriteNode.size = CGSize(width: width, height: height)
            spriteNode.position = CGPoint(x: scene.frame.midX, y: scene.frame.midY)
            spriteNode.lightingBitMask = 1
                      
            scene.addChild(spriteNode)

            // 设置光源
            let lightNode = SKLightNode()
            self.lightNode = lightNode
            lightNode.name = "lightNode"
            lightNode.lightColor = UIColor.white
            lightNode.ambientColor = UIColor.white
            lightNode.shadowColor = UIColor.white
            lightNode.falloff = 1
            lightNode.isEnabled = true
            lightNode.position = CGPoint(x: 0, y: 0) // 初始光源位置
            spriteNode.addChild(lightNode)

            // 设置场景视图
            sceneView.presentScene(scene)
        }

        startGravityUpdates()
    }
    
    func startGravityUpdates() {
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.1  // 每隔 0.1 秒更新一次
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
                if let acceleration = data?.acceleration {
                    self?.updateLightPosition(gravity: acceleration)
                }
            }
        }
    }
    
    func updateLightPosition(gravity: CMAcceleration) {
        // 通过加速度数据来改变光源的位置
       
        if let lightNode = self.lightNode {
            
            let dx = (self.scene?.frame.width ?? 0) / 2.0
            let dy = (self.scene?.frame.height ?? 0) / 2.0
            let x = CGFloat(gravity.x) * dx  // 依据加速度数据调整 x 轴
            let y = (CGFloat(gravity.y) + 0.5) * dy  // 依据加速度数据调整 y 轴
            
            print("x:\(x) y:\(y)")
            
            lightNode.position = CGPoint(x: x, y: y)
        }
    }
    
    func viewwillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        motionManager.stopAccelerometerUpdates()
    }
}
