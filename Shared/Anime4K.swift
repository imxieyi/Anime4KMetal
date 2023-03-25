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
import MetalKit

class Anime4K {
    #if targetEnvironment(macCatalyst)
    static let bufferCount = 3
    #else
    static let bufferCount = 2
    #endif
    
    let name: String
    let shaders: [MPVShader]
    let libraries: [MTLLibrary]
    let defaultLibrary: MTLLibrary
    
    var enabledShaders: [MPVShader]
    var pipelineStates: [MTLComputePipelineState]
    var finalResizePS: MTLComputePipelineState!
    var textureMap: [[String : MTLTexture]]
    var samplerStates: [MTLSamplerState]
    var sizeMap: [String: (Float, Float)]
    var bufferIndex = -1
    
    var outputW: Float = 0
    var outputH: Float = 0
    var textureInW: Float = 0
    var textureInH: Float = 0
    var displayActualW: Float = 0
    var displayActualH: Float = 0
    
    init(_ name: String, subdir: String, device: MTLDevice) throws {
        self.name = name
        self.enabledShaders = []
        self.samplerStates = []
        self.pipelineStates = []
        self.textureMap = []
        self.sizeMap = [:]
        guard let glslFile = Bundle(for: Anime4K.self).url(forResource: name, withExtension: nil, subdirectory: "glsl/" + subdir) else {
            throw Anime4KError.fileNotFound(name)
        }
        let data = try Data(contentsOf: glslFile)
        guard let glsl = String(data: data, encoding: .utf8) else {
            throw Anime4KError.fileCorrupt(name)
        }
        shaders = try MPVShader.parse(glsl)
        print("Trying to compile GLSL shaders in " + name)
        libraries = try shaders.map { shader in
            print("Metal code for " + shader.name)
            print(shader.metalCode)
            let options = MTLCompileOptions()
            options.fastMathEnabled = false
            return try device.makeLibrary(source: shader.metalCode, options: options)
        }
        defaultLibrary = try device.makeDefaultLibrary(bundle: .main)
    }
    
    func compileShaders(_ device: MTLDevice, videoInW: Int, videoInH: Int, textureInW: Int, textureInH: Int, displayOutW: Int, displayOutH: Int) throws {
        enabledShaders.removeAll()
        samplerStates.removeAll()
        pipelineStates.removeAll()
        textureMap.removeAll()
        sizeMap.removeAll()
        bufferIndex = -1
        self.textureInW = Float(textureInW)
        self.textureInH = Float(textureInH)
        let displayScale = min(Float(displayOutW) / Float(videoInW), Float(displayOutH) / Float(videoInH))
        displayActualW = displayScale * Float(videoInW)
        displayActualH = displayScale * Float(videoInH)
        self.outputW = self.textureInW
        self.outputH = self.textureInH
        sizeMap["MAIN"] = (Float(videoInW), Float(videoInH))
        sizeMap["NATIVE"] = (Float(videoInW), Float(videoInH))
        sizeMap["OUTPUT"] = (Float(displayActualW), Float(displayActualH))
        for i in 0..<shaders.count {
            let shader = shaders[i]
            
            // Evaluate WHEN condition using Reverse Polish notation
            if let when = shader.when {
                let splits = when.split(separator: " ").compactMap { item -> Substring? in
                    if item == "WHEN" || item == "" {
                        return nil
                    }
                    return item
                }
                var stack: [Float] = []
                for token in splits {
                    let tSplits = token.split(separator: ".")
                    if tSplits.count == 2 {
                        if tSplits[1] == "w" {
                            stack.append(sizeMap[String(tSplits[0])]!.0)
                            continue
                        } else if tSplits[1] == "h" {
                            stack.append(sizeMap[String(tSplits[0])]!.1)
                            continue
                        }
                    }
                    if ["+", "-", "*", "/", "<", ">"].contains(token) {
                        let rhs = stack.removeLast()
                        let lhs = stack.removeLast()
                        switch token {
                        case "+":
                            stack.append(lhs + rhs)
                        case "-":
                            stack.append(lhs - rhs)
                        case "*":
                            stack.append(lhs * rhs)
                        case "/":
                            stack.append(lhs / rhs)
                        case "<":
                            stack.append(lhs < rhs ? 1 : 0)
                        case ">":
                            stack.append(lhs > rhs ? 1 : 0)
                        default:
                            fatalError("Should not reach here")
                        }
                        continue
                    }
                    stack.append(Float(token)!)
                }
                guard stack.count == 1 else {
                    throw Anime4KError.encoderFail("Failed to evaluate WHEN condition: \(when)")
                }
                if stack.removeLast() == 0 {
                    print("Skip shader \(shader.name)")
                    continue
                }
            }
            
            enabledShaders.append(shader)
            let library = libraries[i]
            self.outputW = self.textureInW
            self.outputH = self.textureInH
            if let hooked = shader.hook {
                sizeMap["HOOKED"] = sizeMap[hooked]
            }
            if let widthMultiplier = shader.width {
                self.outputW = sizeMap[widthMultiplier.0]!.0 * widthMultiplier.1
            }
            if let heightMultiplier = shader.height {
                self.outputH = sizeMap[heightMultiplier.0]!.1 * heightMultiplier.1
            }
            if let save = shader.save, save != "MAIN" {
                sizeMap[save] = (self.outputW, self.outputH)
            }
            pipelineStates.append(try device.makeComputePipelineState(function: library.makeFunction(name: shader.functionName)!))
        }
        finalResizePS = try device.makeComputePipelineState(function: defaultLibrary.makeFunction(name: "CenterResize")!)
    }
    
    func encode(_ device: MTLDevice, cmdBuf: MTLCommandBuffer, input: MTLTexture) throws -> MTLTexture {
        guard pipelineStates.count == enabledShaders.count else {
            throw Anime4KError.encoderFail("Pipeline state count \(pipelineStates.count) mismatch shader count \(shaders.count)")
        }
        if enabledShaders.isEmpty {
            return input
        }
        bufferIndex = (bufferIndex + 1) % Anime4K.bufferCount
        if textureMap.count <= bufferIndex {
            textureMap.append([:])
            let desc = MTLSamplerDescriptor()
            desc.magFilter = .linear
            desc.minFilter = .nearest
            desc.sAddressMode = .clampToEdge
            desc.tAddressMode = .clampToEdge
            let sampler = device.makeSamplerState(descriptor: desc)!
            samplerStates.append(sampler)
        }
        
        textureMap[bufferIndex]["MAIN"] = input
        textureMap[bufferIndex]["NATIVE"] = input
        
        let desc = MTLTextureDescriptor()
        desc.width = Int(outputW)
        desc.height = Int(outputH)
        desc.pixelFormat = .rgba16Float
        desc.usage = [.shaderWrite, .shaderRead]
        desc.storageMode = .private
        textureMap[bufferIndex]["output"] = device.makeTexture(descriptor: desc)
        
        for i in 0..<enabledShaders.count {
            let shader = enabledShaders[i]
            var outputW = textureInW
            var outputH = textureInH
            if let hooked = shader.hook {
                sizeMap["HOOKED"] = sizeMap[hooked]
            }
            if let widthMultiplier = shader.width {
                outputW = sizeMap[widthMultiplier.0]!.0 * widthMultiplier.1
            }
            if let heightMultiplier = shader.height {
                outputH = sizeMap[heightMultiplier.0]!.1 * heightMultiplier.1
            }
            guard let encoder = cmdBuf.makeComputeCommandEncoder() else {
                throw Anime4KError.encoderCreationFail(shader.functionName)
            }
            let pipelineState = pipelineStates[i]
            encoder.setComputePipelineState(pipelineState)
            encoder.setSamplerState(samplerStates[bufferIndex], index: 0)
            for j in 0..<shader.inputTextureNames.count {
                var textureName = shader.inputTextureNames[j]
                if textureName == "HOOKED", let hook = shader.hook {
                    textureName = hook
                }
                if !textureMap[bufferIndex].keys.contains(textureName) {
                    if textureName == shader.save {
                        let desc = MTLTextureDescriptor()
                        desc.width = Int(outputW)
                        desc.height = Int(outputH)
                        desc.pixelFormat = .rgba16Float
                        desc.usage = [.shaderWrite, .shaderRead]
                        desc.storageMode = .private
                        textureMap[bufferIndex][textureName] = device.makeTexture(descriptor: desc)
                    } else {
                        throw Anime4KError.encoderFail("texture \(textureName) is missing")
                    }
                }
                encoder.setTexture(textureMap[bufferIndex][textureName], index: j)
            }
            if shader.binds.contains(shader.outputTextureName) || !textureMap[bufferIndex].keys.contains(shader.outputTextureName) {
                let desc = MTLTextureDescriptor()
                desc.width = Int(outputW)
                desc.height = Int(outputH)
                desc.pixelFormat = .rgba16Float
                desc.usage = [.shaderWrite, .shaderRead]
                desc.storageMode = .private
                textureMap[bufferIndex][shader.outputTextureName] = device.makeTexture(descriptor: desc)
            }
            let outputTex = textureMap[bufferIndex][shader.outputTextureName]!
            encoder.setTexture(outputTex, index: shader.inputTextureNames.count)
            let w = pipelineState.threadExecutionWidth
            let h = pipelineState.maxTotalThreadsPerThreadgroup / w
            let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
            let threadgroupsPerGrid = MTLSize(width: (outputTex.width + w - 1) / w,
                                              height: (outputTex.height + h - 1) / h,
                                              depth: outputTex.arrayLength)
            encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            encoder.endEncoding()
        }
        return textureMap[bufferIndex]["output"]!
    }
    
    func encode(_ device: MTLDevice, cmdBuf: MTLCommandBuffer, input: MTLTexture, output: MTLTexture) throws {
        let outTex = try encode(device, cmdBuf: cmdBuf, input: input)
        let encoder = cmdBuf.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(finalResizePS)
        encoder.setTexture(outTex, index: 0)
        encoder.setTexture(output, index: 1)
        let w = finalResizePS.threadExecutionWidth
        let h = finalResizePS.maxTotalThreadsPerThreadgroup / w
        let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
        let threadgroupsPerGrid = MTLSize(width: (output.width + w - 1) / w,
                                          height: (output.height + h - 1) / h,
                                          depth: output.arrayLength)
        encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
    }
    
}

enum Anime4KError: Error, LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .fileNotFound(msg):
            return "Cannot find file: " + msg
        case let .fileCorrupt(msg):
            return "Cannot read file: " + msg
        case let .encoderCreationFail(msg):
            return "Cannot create encoder for " + msg
        case let .encoderFail(msg):
            return "Failed to encode: " + msg
        }
    }
    case fileNotFound(String)
    case fileCorrupt(String)
    case encoderCreationFail(String)
    case encoderFail(String)
}
