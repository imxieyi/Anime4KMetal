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

import SwiftUI
import Combine

struct ContentView: View {
    
    @State var shaders: [String] = []
    @State var selected: String = "Upscale+Denoise/Anime4K_Upscale_Denoise_CNN_x2_S.glsl"
    @State var videoUrl: String = ""
    @State var localFileUrl: URL = URL(fileURLWithPath: "file:///")
    @State var playerViewItem: PlayerViewItem? = nil
    @State var showFileImporter = false
    
    var body: some View {
        #if os(tvOS)
        NavigationView {
            form
        }
        #else
        form
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.movie]) { result in
            localFileUrl = try! result.get()
            playerViewItem = .local
        }
        #endif
    }
    
    var form: some View {
        Form {
            Section {
                Picker("Pick a shader", selection: $selected) {
                    ForEach(shaders, id: \.self) {
                        Text($0)
                    }
                }
            } header: {
                Text("Shader selection")
            }
            Section {
                TextField("Input URL", text: $videoUrl)
                    .onSubmit {
                        UserDefaults.standard.set(videoUrl, forKey: "video_url")
                    }
                Button("Play") {
                    playerViewItem = .remote
                }
                .disabled(videoUrl.count == 0)
            } header: {
                Text("Remote file")
            }
            Section {
                Button("Select file") {
                    showFileImporter.toggle()
                }
            } header: {
                Text("Local file")
            }
        }.onAppear {
            videoUrl = UserDefaults.standard.string(forKey: "video_url") ?? ""
            shaders.removeAll()
            let glslDir = Bundle.main.url(forResource: "glsl", withExtension: nil)!
            let glslContent = try! FileManager.default.contentsOfDirectory(atPath: glslDir.path)
            for subdir in glslContent {
                let glsls = try! FileManager.default.contentsOfDirectory(atPath: glslDir.appendingPathComponent(subdir).path)
                for glsl in glsls {
                    shaders.append(subdir + "/" + glsl)
                }
            }
            shaders = shaders.sorted()
        }
        .fullScreenCover(item: $playerViewItem) { item in
            if item == .remote {
                if #available(tvOS 15.0, *) {
                    PlayerView(shader: selected, videoUrl: URL(string: videoUrl)!)
                        .ignoresSafeArea()
                } else {
                    PlayerView(shader: selected, videoUrl: URL(string: videoUrl)!)
                }
            } else if item == .local {
                if #available(tvOS 15.0, *) {
                    PlayerView(shader: selected, videoUrl: localFileUrl)
                        .ignoresSafeArea()
                } else {
                    PlayerView(shader: selected, videoUrl: localFileUrl)
                }
            }
        }
    }
}

enum PlayerViewItem: String, Identifiable {
    var id: String { rawValue }
    case remote
    case local
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
