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
import SwiftUI

struct PlayerView: UIViewControllerRepresentable {
    
    let shader: String?
    let videoUrl: URL
    
    func makeUIViewController(context: Context) -> PlayerController {
        let controller = PlayerController()
        controller.device = MTLCreateSystemDefaultDevice()!
        controller.videoUrl = videoUrl
        if let shader = shader {
            controller.shader = shader
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: PlayerController, context: Context) {
        uiViewController.videoUrl = videoUrl
        if let shader = shader {
            uiViewController.shader = shader
        }
    }
    
}
