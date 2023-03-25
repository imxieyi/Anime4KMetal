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
    
    let name: String
    let shaders: [MPVShader]
    var pipelineStates: [MTLComputePipelineState]
    var textureMap: [String : MTLTexture]
    
    init(_ name: String, subdir: String) throws {
        self.name = name
        self.pipelineStates = []
        self.textureMap = [:]
        guard let glslFile = Bundle(for: Anime4K.self).url(forResource: name, withExtension: nil, subdirectory: "glsl/" + subdir) else {
            throw Anime4KError.fileNotFound(name)
        }
        let data = try Data(contentsOf: glslFile)
        guard let glsl = String(data: data, encoding: .utf8) else {
            throw Anime4KError.fileCorrupt(name)
        }
        shaders = try MPVShader.parse(glsl)
    }
    
    func compileShaders(_ device: MTLDevice, inW: Int, inH: Int, outW: Int, outH: Int) throws {
        pipelineStates.removeAll()
        textureMap.removeAll()
        print("Trying to compile GLSL shaders in " + name)
        try shaders.forEach { shader in
            print("Metal code for " + shader.name)
            print(shader.metalCode)
            var inputW = Float(inW)
            var inputH = Float(inH)
            var outputW = inputW
            var outputH = inputH
            if let widthMultiplier = shader.width?.1 {
                outputW = Float(Double(outputW) * widthMultiplier)
            }
            if let heightMultiplier = shader.height?.1 {
                outputH = Float(Double(outputH) * heightMultiplier)
            }
            var textureW = outputW
            var textureH = outputH
            if shader.outputTextureName == "output" {
                textureW = Float(outW)
                textureH = Float(outH)
            }
            let constants = MTLFunctionConstantValues()
            constants.setConstantValue(&inputW, type: .float, index: 0)
            constants.setConstantValue(&inputH, type: .float, index: 1)
            constants.setConstantValue(&outputW, type: .float, index: 2)
            constants.setConstantValue(&outputH, type: .float, index: 3)
            constants.setConstantValue(&textureW, type: .float, index: 4)
            constants.setConstantValue(&textureH, type: .float, index: 5)
            pipelineStates.append(try device.makeComputePipelineState(function: try device.makeLibrary(source: shader.metalCode, options: nil).makeFunction(name: shader.functionName, constantValues: constants)))
        }
    }
    
    func encode(_ device: MTLDevice, cmdBuf: MTLCommandBuffer, input: MTLTexture, output: MTLTexture) throws {
        guard pipelineStates.count == shaders.count else {
            return
        }
        textureMap["MAIN"] = input
        textureMap["output"] = output
        
        for i in 0..<shaders.count {
            let shader = shaders[i]
            var outputW = Float(input.width)
            var outputH = Float(input.height)
            if let widthMultiplier = shader.width?.1 {
                outputW = Float(Double(outputW) * widthMultiplier)
            }
            if let heightMultiplier = shader.height?.1 {
                outputH = Float(Double(outputH) * heightMultiplier)
            }
            guard let encoder = cmdBuf.makeComputeCommandEncoder() else {
                throw Anime4KError.encoderCreationFail(shader.functionName)
            }
            let pipelineState = pipelineStates[i]
            encoder.setComputePipelineState(pipelineState)
            for j in 0..<shader.inputTextureNames.count {
                var textureName = shader.inputTextureNames[j]
                if textureName == "HOOKED", let hook = shader.hook {
                    textureName = hook
                }
                if !textureMap.keys.contains(textureName) {
                    if textureName == shader.save {
                        let desc = MTLTextureDescriptor()
                        desc.width = Int(outputW)
                        desc.height = Int(outputH)
                        desc.pixelFormat = .rgba16Float
                        desc.usage = [.shaderWrite, .shaderRead]
                        desc.storageMode = .private
                        textureMap[textureName] = device.makeTexture(descriptor: desc)
                    } else {
                        throw Anime4KError.encoderFail("texture \(textureName) is missing")
                    }
                }
                encoder.setTexture(textureMap[textureName], index: j)
            }
            if shader.binds.contains(shader.outputTextureName) || !textureMap.keys.contains(shader.outputTextureName) {
                let desc = MTLTextureDescriptor()
                desc.width = Int(outputW)
                desc.height = Int(outputH)
                desc.pixelFormat = .rgba16Float
                desc.usage = [.shaderWrite, .shaderRead]
                desc.storageMode = .private
                textureMap[shader.outputTextureName] = device.makeTexture(descriptor: desc)
            }
            encoder.setTexture(textureMap[shader.outputTextureName], index: shader.inputTextureNames.count)
            let w = pipelineState.threadExecutionWidth
            let h = pipelineState.maxTotalThreadsPerThreadgroup / w
            let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
            let threadgroupsPerGrid = MTLSize(width: (output.width + w - 1) / w,
                                              height: (output.height + h - 1) / h,
                                              depth: output.arrayLength)
            encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            encoder.endEncoding()
        }
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
