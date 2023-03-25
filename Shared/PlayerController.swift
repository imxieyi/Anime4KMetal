// Copyright 2021 Yi Xie
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import AVKit
import MetalKit
import UIKit
import Atomics

class PlayerController: AVPlayerViewController, MTKViewDelegate {

    var device: MTLDevice!
    private var mtkView: MTKView!
    private var perfBanner: UILabel!
    
    private var commandQueue: MTLCommandQueue!
    
    private var pixelBuffer: CVPixelBuffer?
    private var textureCache: CVMetalTextureCache!
    
    private var lastFrameTime: Double = 0
    
    private var anime4K: Anime4K!
    
    private var inW: Int = 0
    private var inH: Int = 0
    private var outW: Int = 0
    private var outH: Int = 0
    
    var isShowing = false
    
    var videoUrl: URL? {
        didSet {
            if isShowing {
                playVideo()
            }
        }
    }
    
    var shader: String? {
        didSet {
            if let shader = shader, shader.count > 0 {
                let splits = shader.split(separator: "/")
                anime4K = try! Anime4K(String(splits[1]), subdir: String(splits[0]), device: device)
            }
        }
    }
    
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
        commandQueue = device.makeCommandQueue()!
        var textureCache: CVMetalTextureCache?
        guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache) == kCVReturnSuccess else {
            fatalError("Failed to create texture cache")
        }
        self.textureCache = textureCache!
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard !(player?.isPlaying ?? false) else {
            return
        }
        // Hack: hide native video view but remain controls
        #if os(tvOS)
        view.subviews[0].isHidden = true
        #endif
        // Setup MTKView
        mtkView = MTKView(frame: view.frame, device: device)
        mtkView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(mtkView, at: 0)
        mtkView.delegate = self
        mtkView.framebufferOnly = false
        mtkView.autoResizeDrawable = true
        mtkView.contentMode = .scaleAspectFit
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = true
        mtkView.contentScaleFactor = 1
        // Setup performance banner
        perfBanner = UILabel()
        perfBanner.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(perfBanner, at: 1)
        perfBanner.backgroundColor = .black
        perfBanner.textColor = .white
        perfBanner.alpha = 0.5
        perfBanner.textAlignment = .left
        perfBanner.font = .monospacedSystemFont(ofSize: 20, weight: .regular)
        view.addConstraints([
            NSLayoutConstraint(item: mtkView!, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: mtkView!, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: mtkView!, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: mtkView!, attribute: .trailing, relatedBy: .equal, toItem: view, attribute: .trailing, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: perfBanner!, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 28),
            NSLayoutConstraint(item: perfBanner!, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: perfBanner!, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: perfBanner!, attribute: .trailing, relatedBy: .equal, toItem: view, attribute: .trailing, multiplier: 1, constant: 0),
        ])
    }
    
    func playVideo() {
        guard let videoUrl = videoUrl else {
            return
        }
        #if os(tvOS)
        appliesPreferredDisplayCriteriaAutomatically = true
        #endif
        let playerItem = AVPlayerItem(url: videoUrl)
        playerItem.add(videoOutput)
        player = AVPlayer(playerItem: playerItem)
        player?.preventsDisplaySleepDuringVideoPlayback = true
        displayLink.isPaused = false
        player?.play()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !(player?.isPlaying ?? false) else {
            return
        }
        #if os(iOS)
        view.subviews[2].subviews[0].isHidden = true
        #endif
        playVideo()
        isShowing = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isShowing = false
        anime4K = nil
        player?.replaceCurrentItem(with: nil)
        displayLink.invalidate()
    }
    
    var inFlightFrames = ManagedAtomic(0)
    var frameDrops = 0
    
    @objc private func readBuffer(_ sender: CADisplayLink) {
        if inFlightFrames.load(ordering: .sequentiallyConsistent) >= 3 {
            print("Dropping frame")
            frameDrops += 1
            return
        }
        let nextVSync = sender.timestamp + sender.duration
        let currentTime = videoOutput.itemTime(forHostTime: nextVSync)
        guard videoOutput.hasNewPixelBuffer(forItemTime: currentTime) else {
            return
        }
        guard let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: nil) else {
            return
        }
        self.pixelBuffer = pixelBuffer
        inFlightFrames.wrappingIncrement(ordering: .sequentiallyConsistent)
        mtkView.setNeedsDisplay()
    }
    
    func draw(in view: MTKView) {
        autoreleasepool {
            if !render(in: view) {
                self.inFlightFrames.wrappingDecrement(ordering: .sequentiallyConsistent)
            }
        }
    }
    
    let cpuOverheadAverage = Average(count: 10)
    
    private func render(in view: MTKView) -> Bool {
        let startRenderTime = CACurrentMediaTime()
        guard let pixelBuffer = self.pixelBuffer else {
            return false
        }
        
        let inW = CVPixelBufferGetWidth(pixelBuffer)
        let inH = CVPixelBufferGetHeight(pixelBuffer)
        
        var cvTexture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer, nil, .bgra8Unorm, inW, inH, 0, &cvTexture)
        guard cvTexture != nil, let textureIn = CVMetalTextureGetTexture(cvTexture!) else {
            NSLog("Failed to create metal texture")
            return false
        }
        guard let drawable = view.currentDrawable else {
            return false
        }
        
        let outW = Int(view.frame.width * UIScreen.main.scale)
        let outH = Int(view.frame.height * UIScreen.main.scale)
        
        if self.inW != inW || self.inH != inH || self.outW != outW || self.outH != outH {
            guard anime4K != nil else {
                return false
            }
            self.inW = inW
            self.inH = inH
            self.outW = outW
            self.outH = outH
            try! anime4K.compileShaders(device, inW: inW, inH: inH, outW: outW, outH: outH)
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return false
        }

        try! anime4K.encode(device, cmdBuf: commandBuffer, input: textureIn, output: drawable.texture)
        commandBuffer.present(drawable)
        let endEncodeTime = CACurrentMediaTime()
        commandBuffer.addCompletedHandler { _ in
            self.inFlightFrames.wrappingDecrement(ordering: .sequentiallyConsistent)
            DispatchQueue.main.async {
                let currentTime = CACurrentMediaTime()
                if self.lastFrameTime != 0 {
                    let overhead = endEncodeTime - startRenderTime
                    self.perfBanner.text = String(format: "CPU: %02.1fms  Queued: %d/3  Dropped: %d  In: %dx%d  Out: %dx%d  Shader: %@", self.cpuOverheadAverage.update(overhead * 1000), self.inFlightFrames.load(ordering: .sequentiallyConsistent), self.frameDrops, inW, inH, Int(outW), Int(outH), self.shader ?? "unknown")
                }
                self.lastFrameTime = currentTime
            }
        }
        commandBuffer.commit()
        return true
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
    
}

extension AVPlayer {
    var isPlaying: Bool {
        return rate != 0 && error == nil
    }
}
