//
//  ViewController.swift
//  normalMap
//
//  Created by Tony on 2025/4/16.
//

import UIKit
import Accelerate
import CoreImage
import MetalKit

class ViewController: UIViewController, UIImagePickerControllerDelegate & UINavigationControllerDelegate {
    
    let orginImageView = UIImageView()
    let normalMapImageView = UIImageView()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let button = UIButton(type: .custom)
        button.setTitle("选择图片", for: .normal)
        button.setTitleColor(UIColor.black, for: .normal)
        button.center = CGPoint(x: self.view.bounds.width / 2, y: 100)
        button.bounds = CGRect(x: 0, y: 0, width: 100, height: 50)
        self.view.addSubview(button)
        button.addTarget(self, action: #selector(clickAction), for: .touchUpInside)
        
        orginImageView.center = CGPoint(x: self.view.bounds.width / 2, y: 200)
        orginImageView.bounds = CGRect(x: 0, y: 0, width: 100, height: 60)
        self.view.addSubview(orginImageView)
        
        normalMapImageView.center = CGPoint(x: self.view.bounds.width / 2, y: 300)
        normalMapImageView.bounds = CGRect(x: 0, y: 0, width: 100, height: 60)
        self.view.addSubview(normalMapImageView)
    }

    @objc func clickAction() {
        let pickerVC = UIImagePickerController()
        pickerVC.delegate = self
        self.present(pickerVC, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            print("选中的图片：", image)
            self.orginImageView.image = image
//            self.normalMapImageView.image = self.generateNormalMap(from: image,intensity: 20.0)
            let normalMapTool = MetalNormalMapRenderer()
            let mapImage = normalMapTool?.generateNormalMap(from: image)
            self.normalMapImageView.image = mapImage
            let mapVC = ReflectImageViewController()
            mapVC.orginImage = image
            mapVC.normalMappingImage = mapImage
            self.navigationController?.pushViewController(mapVC, animated: true)
        }
        picker.dismiss(animated: true)
    }
    
    func generateNormalMap(from image: UIImage, intensity: Float = 2.0) -> UIImage? {
            // Step 1: 转换为灰度图
            guard let grayImage = convertToGrayscale(image: image),
                  let cgImage = grayImage.cgImage else { return nil }
            
            // Step 2: 提取像素数据
            let width = cgImage.width
            let height = cgImage.height
            let bytesPerPixel = 4
            let bytesPerRow = bytesPerPixel * width
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
            
            guard let context = CGContext(data: &pixelData,
                                          width: width,
                                          height: height,
                                          bitsPerComponent: 8,
                                          bytesPerRow: bytesPerRow,
                                          space: colorSpace,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            
            // Step 3: Sobel算子计算梯度
            let (dx, dy) = calculateSobelGradients(pixelData: pixelData, width: width, height: height)
            
            // Step 4: 生成法线向量并编码为RGB
            let normalMapData = generateNormalMapData(dx: dx, dy: dy, intensity: intensity, width: width, height: height)
            
            // Step 5: 转换为UIImage
            let mapImage = createImageFromRGBData(data: normalMapData, width: width, height: height)
            return mapImage
        }
        
        // MARK: - 核心算法步骤
        
        /// 转换为灰度图（使用Core Image滤镜）[6](@ref)
        func convertToGrayscale(image: UIImage) -> UIImage? {
            guard let ciImage = CIImage(image: image) else { return nil }
            let filter = CIFilter(name: "CIColorControls", parameters: [
                kCIInputImageKey: ciImage,
                kCIInputSaturationKey: 0.0
            ])
            return filter?.outputImage?.convertToUIImage()
        }
        
        /// 计算Sobel梯度（基于OpenCV算法移植）[1,7](@ref)
        func calculateSobelGradients(pixelData: [UInt8], width: Int, height: Int) -> (dx: [Float], dy: [Float]) {
            var dx = [Float](repeating: 0, count: width * height)
            var dy = [Float](repeating: 0, count: width * height)
            
            let sobelX: [Float] = [-1, 0, 1, -2, 0, 2, -1, 0, 1]
            let sobelY: [Float] = [-1, -2, -1, 0, 0, 0, 1, 2, 1]
            
            for y in 1..<height-1 {
                for x in 1..<width-1 {
                    var sumX: Float = 0
                    var sumY: Float = 0
                    for ky in -1...1 {
                        for kx in -1...1 {
                            let index = (y + ky) * width + (x + kx)
                            let gray = Float(pixelData[index * 4]) / 255.0 // 取R通道（灰度值）
                            let kernelIndex = (ky + 1) * 3 + (kx + 1)
                            sumX += gray * sobelX[kernelIndex]
                            sumY += gray * sobelY[kernelIndex]
                        }
                    }
                    dx[y * width + x] = sumX
                    dy[y * width + x] = sumY
                }
            }
            return (dx, dy)
        }
        
        /// 生成法线贴图数据（包含归一化处理）[3](@ref)
        func generateNormalMapData(dx: [Float], dy: [Float], intensity: Float, width: Int, height: Int) -> [UInt8] {
            var normalData = [UInt8](repeating: 0, count: width * height * 4)
            let strength = intensity / 255.0
            
            for i in 0..<dx.count {
                let x = dx[i] * strength
                let y = dy[i] * strength
                let z = sqrt(1.0 - x*x - y*y)
                
                // 归一化并映射到[0,255]
                let r = UInt8((x + 1.0) * 127.5)
                let g = UInt8((y + 1.0) * 127.5)
                let b = UInt8((z + 1.0) * 127.5)
                
                normalData[i*4] = r     // R通道对应法线X分量
                normalData[i*4+1] = g   // G通道对应法线Y分量
                normalData[i*4+2] = b   // B通道对应法线Z分量
                normalData[i*4+3] = 255 // Alpha通道
            }
            return normalData
        }
        
        /// 从RGB数据生成UIImage[6](@ref)
        func createImageFromRGBData(data: [UInt8], width: Int, height: Int) -> UIImage? {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            
            guard let providerRef = CGDataProvider(data: Data(bytes: data, count: data.count) as CFData),
                  let cgImage = CGImage(width: width,
                                        height: height,
                                        bitsPerComponent: 8,
                                        bitsPerPixel: 32,
                                        bytesPerRow: width * 4,
                                        space: colorSpace,
                                        bitmapInfo: bitmapInfo,
                                        provider: providerRef,
                                        decode: nil,
                                        shouldInterpolate: false,
                                        intent: .defaultIntent) else { return nil }
            return UIImage(cgImage: cgImage)
        }

}

extension CIImage {
    func convertToUIImage() -> UIImage? {
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(self, from: self.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

extension UIImage {
    /// 返回垂直翻转后的图像
    func verticallyFlipped() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return nil
        }
        // 翻转上下文，这里先平移再缩放
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        // 绘制原图
        self.draw(in: CGRect(origin: .zero, size: size))
        let flippedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return flippedImage
    }
}

class MetalNormalMapRenderer {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLComputePipelineState?

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        self.device = device
        self.commandQueue = commandQueue

        guard let library = device.makeDefaultLibrary(),
              let kernelFunction = library.makeFunction(name: "normalMapKernel") else {
            return nil
        }
        do {
            pipelineState = try device.makeComputePipelineState(function: kernelFunction)
        } catch {
            print("创建 compute pipeline 失败: \(error)")
            return nil
        }
    }
    
    /// 将 UIImage 转换为 MTLTexture
    func texture(from image: UIImage) -> MTLTexture? {
        let textureLoader = MTKTextureLoader(device: self.device)
        do {
            let texture = try textureLoader.newTexture(cgImage: image.cgImage!, options: [
                MTKTextureLoader.Option.SRGB: false,
                MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue)
            ])
            return texture
        } catch {
            print("加载纹理失败: \(error)")
            return nil
        }
    }
    
    /// 利用 GPU（Metal Compute Shader）渲染法线贴图
    func renderNormalMap(from inputTexture: MTLTexture) -> MTLTexture? {
        let width = inputTexture.width
        let height = inputTexture.height
        
        // 输出纹理描述，这里使用 RGBA32Float 格式
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float,
                                                                  width: width,
                                                                  height: height,
                                                                  mipmapped: false)
        descriptor.usage = [.shaderWrite, .shaderRead]
        guard let outputTexture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }
        
        guard let pipelineState = self.pipelineState,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }
        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.setTexture(inputTexture, index: 0)
        commandEncoder.setTexture(outputTexture, index: 1)
        
        let threadGroupSize = MTLSize(width: 8, height: 8, depth: 1)
        let threadGroups = MTLSize(width: (width + threadGroupSize.width - 1) / threadGroupSize.width,
                                   height: (height + threadGroupSize.height - 1) / threadGroupSize.height,
                                   depth: 1)
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        commandEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return outputTexture
    }
    
    /// 方便的方法：直接使用 UIImage 调用生成法线贴图
    func generateNormalMap(from image: UIImage) -> UIImage? {
        guard let inputTexture = texture(from: image) else {
            return nil
        }
        
        guard let outputTexture = renderNormalMap(from: inputTexture) else {
            return nil
        }
        
        // 将输出纹理转换为 UIImage（这里使用 MTKTextureLoader 或手动渲染）
        let ciImage = CIImage(mtlTexture: outputTexture, options: nil)
        let context = CIContext(mtlDevice: device)
        if let ciImage = ciImage,
           let cgImage = context.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: outputTexture.width, height: outputTexture.height)) {
            let normalImage = UIImage(cgImage: cgImage).verticallyFlipped()
            return normalImage
        }
        
        return nil
    }
}
