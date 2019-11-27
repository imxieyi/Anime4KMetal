//
//  Anime4K.swift
//  Anime4K-tvOS
//
//  Created by 谢宜 on 2019/11/26.
//  Copyright © 2019 xieyi. All rights reserved.
//

import Foundation
import Metal
import MetalKit

open class Anime4K {
    
    let device: MTLDevice
    let library: MTLLibrary
    
    let luminanceFunc: MTLFunction
    var lumaFunc: MTLFunction!
    var computeGaussianXFunc: MTLFunction!
    var computeGaussianYFunc: MTLFunction!
    var lineDetectFunc: MTLFunction!
    var computeLineGaussianXFunc: MTLFunction!
    var computeLineGaussianYFunc: MTLFunction!
    var computeGradientXFunc: MTLFunction!
    var computeGradientYFunc: MTLFunction!
    var thinLinesFunc: MTLFunction!
    var refineFunc: MTLFunction!
    var postFXAAFunc: MTLFunction!

    let samplerState: MTLSamplerState
    
    var constants: MTLFunctionConstantValues!
    var scaledTextureDescriptor: MTLTextureDescriptor!
    var lumTextureDescriptor: MTLTextureDescriptor!
    var outTextureDescriptor: MTLTextureDescriptor!
    
    public init(device: MTLDevice) throws {
        self.device = device
        library = try device.makeDefaultLibrary(bundle: Bundle(for: type(of: self)))
        samplerState = Anime4K.makeSamplerState(device: device)
        luminanceFunc = library.makeFunction(name: "Luminance")!
    }
    
    open func updateResolution(inW: Int, inH: Int, outW: Int, outH: Int) {
        // Scaled texture
        scaledTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: MTLPixelFormat.rgba8Unorm, width: outW, height: outH, mipmapped: false)
        scaledTextureDescriptor.usage = MTLTextureUsage(rawValue: MTLTextureUsage.shaderWrite.rawValue | MTLTextureUsage.shaderRead.rawValue)
        scaledTextureDescriptor.storageMode = .private
        // Luminance texture
        lumTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg16Float, width: inW, height: inH, mipmapped: false)
        lumTextureDescriptor.usage = MTLTextureUsage(rawValue: MTLTextureUsage.shaderWrite.rawValue | MTLTextureUsage.shaderRead.rawValue)
        lumTextureDescriptor.storageMode = .private
        // Output texture
        outTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: MTLPixelFormat.rgba8Unorm, width: outW, height: outH, mipmapped: false)
        outTextureDescriptor.usage = .shaderWrite
        outTextureDescriptor.storageMode = .shared
        // Set constants
        var in_w = Float(inW)
        var in_h = Float(inH)
        var out_w = Float(outW)
        var out_h = Float(outH)
        constants = MTLFunctionConstantValues()
        constants.setConstantValue(&in_w,   type: MTLDataType.float, index: 0)
        constants.setConstantValue(&in_h,  type: MTLDataType.float,  index: 1)
        constants.setConstantValue(&out_w,  type: MTLDataType.float,  index: 2)
        constants.setConstantValue(&out_h, type: MTLDataType.float,  index: 3)
        lumaFunc = try! library.makeFunction(name: "Luma", constantValues: constants)
        computeGaussianXFunc = try! library.makeFunction(name: "ComputeGaussianX", constantValues: constants)
        computeGaussianYFunc = try! library.makeFunction(name: "ComputeGaussianY", constantValues: constants)
        lineDetectFunc = try! library.makeFunction(name: "LineDetect", constantValues: constants)
        computeLineGaussianXFunc = try! library.makeFunction(name: "ComputeLineGaussianX", constantValues: constants)
        computeLineGaussianYFunc = try! library.makeFunction(name: "ComputeLineGaussianY", constantValues: constants)
        computeGradientXFunc = try! library.makeFunction(name: "ComputeGradientX", constantValues: constants)
        computeGradientYFunc = try! library.makeFunction(name: "ComputeGradientY", constantValues: constants)
        thinLinesFunc = try! library.makeFunction(name: "ThinLines", constantValues: constants)
        refineFunc = try! library.makeFunction(name: "Refine", constantValues: constants)
        postFXAAFunc = try! library.makeFunction(name: "PostFXAA", constantValues: constants)
    }

    // Normalized sampler
    private static func makeSamplerState(device: MTLDevice) -> MTLSamplerState {
        let sampler = MTLSamplerDescriptor()
        sampler.minFilter = .linear
        sampler.magFilter = .linear
        sampler.mipFilter = .notMipmapped
        sampler.maxAnisotropy = 1
        sampler.sAddressMode = .clampToEdge
        sampler.tAddressMode = .clampToEdge
        sampler.rAddressMode = .clampToEdge
        sampler.normalizedCoordinates = true
        sampler.lodMinClamp = 0
        sampler.lodMaxClamp = Float.greatestFiniteMagnitude
        return device.makeSamplerState(descriptor: sampler)!
    }
    
    private func luminance(cmdBuffer: MTLCommandBuffer, rgb: MTLTexture, luma: MTLTexture) {
        let encoder = cmdBuffer.makeComputeCommandEncoder()!
        let pipelineState = try! device.makeComputePipelineState(function: luminanceFunc)
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(rgb, index: 0)
        encoder.setTexture(luma, index: 1)
        let threadGroupCount = MTLSize(width: 20, height: 20, depth: 1)
        let threadGroups = MTLSize(width: luma.width / threadGroupCount.width, height: luma.height / threadGroupCount.height, depth: 1)
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        encoder.endEncoding()
    }
    
    private func luma(cmdBuffer: MTLCommandBuffer, constants: MTLFunctionConstantValues, hooked: MTLTexture, lumax: MTLTexture) {
        let encoder = cmdBuffer.makeComputeCommandEncoder()!
        let pipelineState = try! device.makeComputePipelineState(function: lumaFunc)
        encoder.setComputePipelineState(pipelineState)
        encoder.setSamplerState(samplerState, index: 0)
        encoder.setTexture(hooked, index: 0)
        encoder.setTexture(lumax, index: 1)
        let threadGroupCount = MTLSize(width: 20, height: 20, depth: 1)
        let threadGroups = MTLSize(width: lumax.width / threadGroupCount.width, height: lumax.height / threadGroupCount.height, depth: 1)
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        encoder.endEncoding()
    }
    
    private func computeGaussianX(cmdBuffer: MTLCommandBuffer, constants: MTLFunctionConstantValues, luma: MTLTexture, lumag: MTLTexture) {
        let encoder = cmdBuffer.makeComputeCommandEncoder()!
        let pipelineState = try! device.makeComputePipelineState(function: computeGaussianXFunc)
        encoder.setComputePipelineState(pipelineState)
        encoder.setSamplerState(samplerState, index: 0)
        encoder.setTexture(luma, index: 0)
        encoder.setTexture(lumag, index: 1)
        let threadGroupCount = MTLSize(width: 20, height: 20, depth: 1)
        let threadGroups = MTLSize(width: lumag.width / threadGroupCount.width, height: lumag.height / threadGroupCount.height, depth: 1)
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        encoder.endEncoding()
    }
    
    private func computeGaussianY(cmdBuffer: MTLCommandBuffer, constants: MTLFunctionConstantValues, lumag: MTLTexture, lumagg: MTLTexture) {
        let encoder = cmdBuffer.makeComputeCommandEncoder()!
        let pipelineState = try! device.makeComputePipelineState(function: computeGaussianYFunc)
        encoder.setComputePipelineState(pipelineState)
        encoder.setSamplerState(samplerState, index: 0)
        encoder.setTexture(lumag, index: 0)
        encoder.setTexture(lumagg, index: 1)
        let threadGroupCount = MTLSize(width: 20, height: 20, depth: 1)
        let threadGroups = MTLSize(width: lumagg.width / threadGroupCount.width, height: lumagg.height / threadGroupCount.height, depth: 1)
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        encoder.endEncoding()
    }
    
    private func lineDetect(cmdBuffer: MTLCommandBuffer, constants: MTLFunctionConstantValues, luma: MTLTexture, lumag: MTLTexture, lumagg: MTLTexture) {
        let encoder = cmdBuffer.makeComputeCommandEncoder()!
        let pipelineState = try! device.makeComputePipelineState(function: lineDetectFunc)
        encoder.setComputePipelineState(pipelineState)
        encoder.setSamplerState(samplerState, index: 0)
        encoder.setTexture(luma, index: 0)
        encoder.setTexture(lumag, index: 1)
        encoder.setTexture(lumagg, index: 2)
        let threadGroupCount = MTLSize(width: 20, height: 20, depth: 1)
        let threadGroups = MTLSize(width: lumagg.width / threadGroupCount.width, height: lumagg.height / threadGroupCount.height, depth: 1)
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        encoder.endEncoding()
    }
    
    private func computeLineGaussianX(cmdBuffer: MTLCommandBuffer, constants: MTLFunctionConstantValues, lumag: MTLTexture, lumagg: MTLTexture) {
        let encoder = cmdBuffer.makeComputeCommandEncoder()!
        let pipelineState = try! device.makeComputePipelineState(function: computeLineGaussianXFunc)
        encoder.setComputePipelineState(pipelineState)
        encoder.setSamplerState(samplerState, index: 0)
        encoder.setTexture(lumag, index: 0)
        encoder.setTexture(lumagg, index: 1)
        let threadGroupCount = MTLSize(width: 20, height: 20, depth: 1)
        let threadGroups = MTLSize(width: lumagg.width / threadGroupCount.width, height: lumagg.height / threadGroupCount.height, depth: 1)
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        encoder.endEncoding()
    }
    
    private func computeLineGaussianY(cmdBuffer: MTLCommandBuffer, constants: MTLFunctionConstantValues, lumag: MTLTexture, lumagg: MTLTexture) {
        let encoder = cmdBuffer.makeComputeCommandEncoder()!
        let pipelineState = try! device.makeComputePipelineState(function: computeLineGaussianYFunc)
        encoder.setComputePipelineState(pipelineState)
        encoder.setSamplerState(samplerState, index: 0)
        encoder.setTexture(lumag, index: 0)
        encoder.setTexture(lumagg, index: 1)
        let threadGroupCount = MTLSize(width: 20, height: 20, depth: 1)
        let threadGroups = MTLSize(width: lumagg.width / threadGroupCount.width, height: lumagg.height / threadGroupCount.height, depth: 1)
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        encoder.endEncoding()
    }
    
    private func computeGradientX(cmdBuffer: MTLCommandBuffer, constants: MTLFunctionConstantValues, luma: MTLTexture, lumad: MTLTexture) {
        let encoder = cmdBuffer.makeComputeCommandEncoder()!
        let pipelineState = try! device.makeComputePipelineState(function: computeGradientXFunc)
        encoder.setComputePipelineState(pipelineState)
        encoder.setSamplerState(samplerState, index: 0)
        encoder.setTexture(luma, index: 0)
        encoder.setTexture(lumad, index: 1)
        let threadGroupCount = MTLSize(width: 20, height: 20, depth: 1)
        let threadGroups = MTLSize(width: lumad.width / threadGroupCount.width, height: lumad.height / threadGroupCount.height, depth: 1)
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        encoder.endEncoding()
    }
    
    private func computeGradientY(cmdBuffer: MTLCommandBuffer, constants: MTLFunctionConstantValues, lumad: MTLTexture, lumadd: MTLTexture) {
        let encoder = cmdBuffer.makeComputeCommandEncoder()!
        let pipelineState = try! device.makeComputePipelineState(function: computeGradientYFunc)
        encoder.setComputePipelineState(pipelineState)
        encoder.setSamplerState(samplerState, index: 0)
        encoder.setTexture(lumad, index: 0)
        encoder.setTexture(lumadd, index: 1)
        let threadGroupCount = MTLSize(width: 20, height: 20, depth: 1)
        let threadGroups = MTLSize(width: lumadd.width / threadGroupCount.width, height: lumadd.height / threadGroupCount.height, depth: 1)
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        encoder.endEncoding()
    }
    
    private func thinLines(cmdBuffer: MTLCommandBuffer, constants: MTLFunctionConstantValues, hooked: MTLTexture, luma: MTLTexture, lumag: MTLTexture, scaled: MTLTexture) {
        let encoder = cmdBuffer.makeComputeCommandEncoder()!
        let pipelineState = try! device.makeComputePipelineState(function: thinLinesFunc)
        encoder.setComputePipelineState(pipelineState)
        encoder.setSamplerState(samplerState, index: 0)
        encoder.setTexture(hooked, index: 0)
        encoder.setTexture(luma, index: 1)
        encoder.setTexture(lumag, index: 2)
        encoder.setTexture(scaled, index: 3)
        let threadGroupCount = MTLSize(width: 20, height: 20, depth: 1)
        let threadGroups = MTLSize(width: scaled.width / threadGroupCount.width, height: scaled.height / threadGroupCount.height, depth: 1)
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        encoder.endEncoding()
    }
    
    private func refine(cmdBuffer: MTLCommandBuffer, constants: MTLFunctionConstantValues, hooked: MTLTexture, luma: MTLTexture, lumag: MTLTexture, lumad: MTLTexture, scaled: MTLTexture) {
        let encoder = cmdBuffer.makeComputeCommandEncoder()!
        let pipelineState = try! device.makeComputePipelineState(function: refineFunc)
        encoder.setComputePipelineState(pipelineState)
        encoder.setSamplerState(samplerState, index: 0)
        encoder.setTexture(hooked, index: 0)
        encoder.setTexture(luma, index: 1)
        encoder.setTexture(lumag, index: 2)
        encoder.setTexture(lumad, index: 3)
        encoder.setTexture(scaled, index: 4)
        let threadGroupCount = MTLSize(width: 20, height: 20, depth: 1)
        let threadGroups = MTLSize(width: scaled.width / threadGroupCount.width, height: scaled.height / threadGroupCount.height, depth: 1)
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        encoder.endEncoding()
    }
    
    private func postFXAA(cmdBuffer: MTLCommandBuffer, constants: MTLFunctionConstantValues, hooked: MTLTexture, lumag: MTLTexture, scaled: MTLTexture) {
        let encoder = cmdBuffer.makeComputeCommandEncoder()!
        let pipelineState = try! device.makeComputePipelineState(function: postFXAAFunc)
        encoder.setComputePipelineState(pipelineState)
        encoder.setSamplerState(samplerState, index: 0)
        encoder.setTexture(hooked, index: 0)
        encoder.setTexture(lumag, index: 1)
        encoder.setTexture(scaled, index: 2)
        let threadGroupCount = MTLSize(width: 20, height: 20, depth: 1)
        let threadGroups = MTLSize(width: scaled.width / threadGroupCount.width, height: scaled.height / threadGroupCount.height, depth: 1)
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        encoder.endEncoding()
    }
    
    open func encode(commandBuffer: MTLCommandBuffer, inputSize: CGSize, outputSize: CGSize, textureIn: MTLTexture, textureOut: MTLTexture) {
        // Luminance
        let luma = device.makeTexture(descriptor: lumTextureDescriptor)!
        luminance(cmdBuffer: commandBuffer, rgb: textureIn, luma: luma)
        // ComputeGaussianX
        let lumaGX = device.makeTexture(descriptor: lumTextureDescriptor)!
        computeGaussianX(cmdBuffer: commandBuffer, constants: constants, luma: luma, lumag: lumaGX)
        // ComputeGaussianY
        let lumaGY = device.makeTexture(descriptor: lumTextureDescriptor)!
        computeGaussianY(cmdBuffer: commandBuffer, constants: constants, lumag: lumaGX, lumagg: lumaGY)
        // LineDetect
        let lumaGL = device.makeTexture(descriptor: lumTextureDescriptor)!
        lineDetect(cmdBuffer: commandBuffer, constants: constants, luma: luma, lumag: lumaGY, lumagg: lumaGL)
        // ComputeLineGaussianX
        let lumaGLX = device.makeTexture(descriptor: lumTextureDescriptor)!
        computeLineGaussianX(cmdBuffer: commandBuffer, constants: constants, lumag: lumaGL, lumagg: lumaGLX)
        // ComputeLineGaussianY
        let lumaGLY = device.makeTexture(descriptor: lumTextureDescriptor)!
        computeLineGaussianY(cmdBuffer: commandBuffer, constants: constants, lumag: lumaGLX, lumagg: lumaGLY)
        // ComputeGradientX
        let lumaDX = device.makeTexture(descriptor: lumTextureDescriptor)!
        computeGradientX(cmdBuffer: commandBuffer, constants: constants, luma: luma, lumad: lumaDX)
        // ComputeGradientY
        let lumaDY = device.makeTexture(descriptor: lumTextureDescriptor)!
        computeGradientY(cmdBuffer: commandBuffer, constants: constants, lumad: lumaDX, lumadd: lumaDY)
        // ThinLines
        let scaledTL = device.makeTexture(descriptor: scaledTextureDescriptor)!
        thinLines(cmdBuffer: commandBuffer, constants: constants, hooked: textureIn, luma: luma, lumag: lumaGLY, scaled: scaledTL)
        // Refine
        let scaledR = device.makeTexture(descriptor: scaledTextureDescriptor)!
        refine(cmdBuffer: commandBuffer, constants: constants, hooked: scaledTL, luma: luma, lumag: lumaGLY, lumad: lumaDY, scaled: scaledR)
        // PostFXAA
        postFXAA(cmdBuffer: commandBuffer, constants: constants, hooked: scaledR, lumag: lumaGLY, scaled: textureOut)
    }
    
}

