//
//  PlayerController.swift
//  Anime4K-tvOS
//
//  Created by 谢宜 on 2019/11/26.
//  Copyright © 2019 xieyi. All rights reserved.
//

import Foundation
import UIKit
import AVKit
import MetalKit

class PlayerController: AVPlayerViewController, MTKViewDelegate {
    
    private var device: MTLDevice!
    private var mtkView: MTKView!
    private var perfBanner: UILabel!
    
    private var commandQueue: MTLCommandQueue!
    private var pipelineState: MTLComputePipelineState!
    
    private var pixelBuffer: CVPixelBuffer?
    private var textureCache: CVMetalTextureCache!
    
    private var lastFrameTime: Double = 0
    
    private var anime4K: Anime4K!
    
    var videoUrl: URL?
    
    lazy var videoOutput = { () -> AVPlayerItemVideoOutput in
        let attributes = [kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA)]
        return AVPlayerItemVideoOutput(pixelBufferAttributes: attributes)
    }()
    
    lazy var displayLink = { () -> CADisplayLink in
        let link = CADisplayLink(target: self, selector: #selector(self.readBuffer(_:)))
        link.add(to: .current, forMode: .default)
        link.isPaused = true
        return link
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        device = MTLCreateSystemDefaultDevice()!
        commandQueue = device.makeCommandQueue()!
        var textureCache: CVMetalTextureCache?
        guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache) == kCVReturnSuccess else {
            fatalError("Failed to create texture cache")
        }
        self.textureCache = textureCache!
        anime4K = try! Anime4K(device: device)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Hack: hide native video view but remain controls
        view.subviews[0].isHidden = true
        // Setup MTKView
        mtkView = MTKView(frame: view.frame, device: device)
        view.insertSubview(mtkView, at: 0)
        mtkView.delegate = self
        mtkView.framebufferOnly = false
        mtkView.autoResizeDrawable = false
        mtkView.contentMode = .scaleAspectFit
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = true
        mtkView.contentScaleFactor = 1
        let width = view.frame.width * UIScreen.main.scale
        let height = view.frame.height * UIScreen.main.scale
        mtkView.drawableSize = CGSize(width: width, height: height)
        // Setup performance banner
        perfBanner = UILabel(frame: CGRect(x: 0, y: view.frame.height - 32, width: view.frame.width, height: 32))
        view.insertSubview(perfBanner, at: 1)
        perfBanner.backgroundColor = .black
        perfBanner.alpha = 0.5
        perfBanner.textAlignment = .left
        perfBanner.font = .monospacedSystemFont(ofSize: 24, weight: .regular)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let videoUrl = videoUrl else {
            return
        }
        appliesPreferredDisplayCriteriaAutomatically = true
        let playerItem = AVPlayerItem(url: videoUrl)
        playerItem.add(videoOutput)
        player = AVPlayer(playerItem: playerItem)
        player?.preventsDisplaySleepDuringVideoPlayback = true
        displayLink.isPaused = false
        player?.play()
    }
    
    @objc private func readBuffer(_ sender: CADisplayLink) {
        let nextVSync = sender.timestamp + sender.duration
        let currentTime = videoOutput.itemTime(forHostTime: nextVSync)
        guard videoOutput.hasNewPixelBuffer(forItemTime: currentTime) else {
            return
        }
        guard let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: nil) else {
            return
        }
        self.pixelBuffer = pixelBuffer
        mtkView.setNeedsDisplay()
    }
    
    func draw(in view: MTKView) {
        autoreleasepool {
            render(in: view)
        }
    }
    
    private func render(in view: MTKView) {
        guard let pixelBuffer = self.pixelBuffer else {
            return
        }
        
        let inW = CVPixelBufferGetWidth(pixelBuffer)
        let inH = CVPixelBufferGetHeight(pixelBuffer)
        
        var cvTexture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer, nil, .bgra8Unorm, inW, inH, 0, &cvTexture)
        guard cvTexture != nil, let textureIn = CVMetalTextureGetTexture(cvTexture!) else {
            NSLog("Failed to create metal texture")
            return
        }
        guard let drawable = view.currentDrawable else {
            return
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        let inputSize = CGSize(width: inW, height: inH)
        let outW = view.frame.width * UIScreen.main.scale
        let outH = view.frame.height * UIScreen.main.scale
        let outputSize = CGSize(width: outW, height: outH)
        anime4K.encode(commandBuffer: commandBuffer, inputSize: inputSize, outputSize: outputSize, textureIn: textureIn, textureOut: drawable.texture)
        commandBuffer.present(drawable)
        commandBuffer.addCompletedHandler { _ in
            DispatchQueue.main.async {
                let currentTime = CACurrentMediaTime()
                if self.lastFrameTime != 0 {
                    let fps = 1.0 / (currentTime - self.lastFrameTime)
                    self.perfBanner.text = String(format: "FPS: %02.2f   Input: %dx%d   Output: %dx%d", fps, inW, inH, Int(outW), Int(outH))
                }
                self.lastFrameTime = currentTime
            }
        }
        commandBuffer.commit()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
    
}
