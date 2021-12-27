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

import XCTest
import MetalKit
@testable import Anime4KMetal

class MPVShaderTests: XCTestCase {
    
    var device: MTLDevice!
    
    override func setUpWithError() throws {
        device = MTLCreateSystemDefaultDevice()
        try XCTSkipIf(device == nil, "Metal is not supported")
    }
    
    func testDeblur() throws {
        try glslTest("Deblur")
    }
    
    func testDenoise() throws {
        try glslTest("Denoise")
    }
    
    func testExperimentalEffects() throws {
        try glslTest("Experimental-Effects")
    }
    
    func testRestore() throws {
        try glslTest("Restore")
    }
    
    func testUpscale() throws {
        try glslTest("Upscale")
    }
    
    func testUpscaleDenoise() throws {
        try glslTest("Upscale+Denoise")
    }
    
    func glslTest(_ subdir: String) throws {
        let dir = Bundle(for: MPVShaderTests.self).url(forResource: subdir, withExtension: nil, subdirectory: "glsl")
        XCTAssertNotNil(dir, "GLSL shader directory not found: " + subdir)
        let files = try FileManager.default.contentsOfDirectory(atPath: dir!.path)
        try files.forEach { file in
            print("Trying to compile " + file)
            let mpvShaders = try MPVShader.parse(try loadGLSL(file, subdir: "glsl/" + subdir))
            print("Compiled functions:")
            try mpvShaders.forEach { mpvShader in
                let library = try device.makeLibrary(source: mpvShader.metalCode, options: nil)
                library.functionNames.forEach { print($0) }
            }
        }
    }
    
    func loadGLSL(_ name: String, subdir: String) throws -> String {
        let url = Bundle(for: MPVShaderTests.self).url(forResource: name, withExtension: nil, subdirectory: subdir)
        XCTAssertNotNil(url, "GLSL not found: " + name)
        let data = try Data(contentsOf: url!)
        let glsl = String(data: data, encoding: .utf8)
        XCTAssertNotNil(glsl, "GLSL cannot be loaded: " + name)
        return glsl!
    }
    
}
