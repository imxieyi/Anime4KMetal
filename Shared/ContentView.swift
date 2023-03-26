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
    @State var selected: [String] = [
    ]
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
        NavigationView {
            form
                .navigationTitle("Anime4K")
                .navigationBarTitleDisplayMode(.inline)
                .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.movie]) { result in
                    localFileUrl = try! result.get()
                    playerViewItem = .local
                }
        }
        .navigationViewStyle(.stack)
        .statusBarHidden()
        .modifier(HideOverlayModifier())
        #endif
    }
    
    var form: some View {
        Form {
            Section {
                ForEach(0..<selected.count, id: \.self) { i in
                    Text(selected[i])
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                selected.remove(at: i)
                            }
                        }
                }
                .onDelete { offsets in
                    selected.remove(atOffsets: offsets)
                }
                .onMove { from, to in
                    selected.move(fromOffsets: from, toOffset: to)
                }
                #if os(tvOS)
                TVMenu(title: "Add shader", count: shaders.count) { i in
                    return shaders[i]
                } action: { i in
                    selected.append(shaders[i])
                }
                TVMenu(title: "Use preset", count: presets.count) { i in
                    return presets[i].0
                } action: { i in
                    selected = presets[i].1
                }
                #else
                HStack {
                    Text("Add shader")
                    Spacer()
                    Menu("Add shader") {
                        ForEach(0..<shaders.count, id: \.self) { i in
                            Button {
                                selected.append(shaders[i])
                            } label: {
                                Text(shaders[i])
                            }
                        }
                    }
                }
                HStack {
                    Text("Use preset")
                    Spacer()
                    Menu("Use preset") {
                        ForEach(0..<presets.count, id: \.self) { i in
                            Button {
                                selected = presets[i].1
                            } label: {
                                Text(presets[i].0)
                            }
                        }
                    }
                }
                #endif
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
        }
        .onAppear {
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
                #if os(tvOS)
                PlayerView(shaders: selected, videoUrl: URL(string: videoUrl)!)
                    .ignoresSafeArea()
                #else
                PlayerView(shaders: selected, videoUrl: URL(string: videoUrl)!)
                    .statusBarHidden()
                    .modifier(HideOverlayModifier())
                #endif
            } else if item == .local {
                #if os(tvOS)
                PlayerView(shaders: selected, videoUrl: localFileUrl)
                    .ignoresSafeArea()
                #else
                PlayerView(shaders: selected, videoUrl: localFileUrl)
                    .statusBarHidden()
                    .modifier(HideOverlayModifier())
                #endif
            }
        }
    }
    
    let presets: [(String, [String])] = [
        ("Anime4K: Mode A (Fast)", [
            "Restore/Anime4K_Clamp_Highlights.glsl",
            "Restore/Anime4K_Restore_CNN_M.glsl",
            "Upscale/Anime4K_Upscale_CNN_x2_M.glsl",
            "Upscale/Anime4K_AutoDownscalePre_x2.glsl",
            "Upscale/Anime4K_AutoDownscalePre_x4.glsl",
            "Upscale/Anime4K_Upscale_CNN_x2_S.glsl",
        ]),
        ("Anime4K: Mode B (Fast)", [
            "Restore/Anime4K_Clamp_Highlights.glsl",
            "Restore/Anime4K_Restore_CNN_Soft_M.glsl",
            "Upscale/Anime4K_Upscale_CNN_x2_M.glsl",
            "Upscale/Anime4K_AutoDownscalePre_x2.glsl",
            "Upscale/Anime4K_AutoDownscalePre_x4.glsl",
            "Upscale/Anime4K_Upscale_CNN_x2_S.glsl",
        ]),
         ("Anime4K: Mode C (Fast)", [
            "Upscale+Denoise/Anime4K_Upscale_Denoise_CNN_x2_M.glsl",
            "Upscale/Anime4K_AutoDownscalePre_x2.glsl",
            "Upscale/Anime4K_AutoDownscalePre_x4.glsl",
            "Upscale/Anime4K_Upscale_CNN_x2_S.glsl",
        ]),
        ("Anime4K: Mode A+A (Fast)", [
            "Restore/Anime4K_Clamp_Highlights.glsl",
            "Restore/Anime4K_Restore_CNN_M.glsl",
            "Upscale/Anime4K_Upscale_CNN_x2_M.glsl",
            "Restore/Anime4K_Restore_CNN_S.glsl",
            "Upscale/Anime4K_AutoDownscalePre_x2.glsl",
            "Upscale/Anime4K_AutoDownscalePre_x4.glsl",
            "Upscale/Anime4K_Upscale_CNN_x2_S.glsl",
        ]),
        ("Anime4K: Mode B+B (Fast)", [
            "Restore/Anime4K_Clamp_Highlights.glsl",
            "Restore/Anime4K_Restore_CNN_Soft_M.glsl",
            "Upscale/Anime4K_Upscale_CNN_x2_M.glsl",
            "Upscale/Anime4K_AutoDownscalePre_x2.glsl",
            "Upscale/Anime4K_AutoDownscalePre_x4.glsl",
            "Restore/Anime4K_Restore_CNN_Soft_S.glsl",
            "Upscale/Anime4K_Upscale_CNN_x2_S.glsl",
        ]),
        ("Anime4K: Mode C+A (Fast)", [
            "Restore/Anime4K_Clamp_Highlights.glsl",
            "Upscale+Denoise/Anime4K_Upscale_Denoise_CNN_x2_M.glsl",
            "Upscale/Anime4K_AutoDownscalePre_x2.glsl",
            "Upscale/Anime4K_AutoDownscalePre_x4.glsl",
            "Restore/Anime4K_Restore_CNN_S.glsl",
            "Upscale/Anime4K_Upscale_CNN_x2_S.glsl",
        ]),
        ("Anime4K: Mode A (HQ)", [
            "Restore/Anime4K_Clamp_Highlights.glsl",
            "Restore/Anime4K_Restore_CNN_VL.glsl",
            "Upscale/Anime4K_Upscale_CNN_x2_VL.glsl",
            "Upscale/Anime4K_AutoDownscalePre_x2.glsl",
            "Upscale/Anime4K_AutoDownscalePre_x4.glsl",
            "Upscale/Anime4K_Upscale_CNN_x2_M.glsl",
        ]),
        ("Anime4K: Mode B (HQ)", [
            "Restore/Anime4K_Clamp_Highlights.glsl",
            "Restore/Anime4K_Restore_CNN_Soft_VL.glsl",
            "Upscale/Anime4K_Upscale_CNN_x2_VL.glsl",
            "Upscale/Anime4K_AutoDownscalePre_x2.glsl",
            "Upscale/Anime4K_AutoDownscalePre_x4.glsl",
            "Upscale/Anime4K_Upscale_CNN_x2_M.glsl",
        ]),
        ("Anime4K: Mode C (HQ)", [
            "Restore/Anime4K_Clamp_Highlights.glsl",
            "Upscale+Denoise/Anime4K_Upscale_Denoise_CNN_x2_VL.glsl",
            "Upscale/Anime4K_AutoDownscalePre_x2.glsl",
            "Upscale/Anime4K_AutoDownscalePre_x4.glsl",
            "Upscale/Anime4K_Upscale_CNN_x2_M.glsl",
        ]),
        ("Anime4K: Mode A+A (HQ)", [
            "Restore/Anime4K_Clamp_Highlights.glsl",
            "Restore/Anime4K_Restore_CNN_VL.glsl",
            "Upscale/Anime4K_Upscale_CNN_x2_VL.glsl",
            "Restore/Anime4K_Restore_CNN_M.glsl",
            "Upscale/Anime4K_AutoDownscalePre_x2.glsl",
            "Upscale/Anime4K_AutoDownscalePre_x4.glsl",
            "Upscale/Anime4K_Upscale_CNN_x2_M.glsl",
        ]),
        ("Anime4K: Mode B+B (HQ)", [
            "Restore/Anime4K_Clamp_Highlights.glsl",
            "Restore/Anime4K_Restore_CNN_Soft_VL.glsl",
            "Upscale/Anime4K_Upscale_CNN_x2_VL.glsl",
            "Upscale/Anime4K_AutoDownscalePre_x2.glsl",
            "Upscale/Anime4K_AutoDownscalePre_x4.glsl",
            "Upscale/Anime4K_Upscale_CNN_x2_M.glsl",
        ]),
        ("Anime4K: Mode C+A (HQ)", [
            "Restore/Anime4K_Clamp_Highlights.glsl",
            "Upscale+Denoise/Anime4K_Upscale_Denoise_CNN_x2_VL.glsl",
            "Upscale/Anime4K_AutoDownscalePre_x2.glsl",
            "Upscale/Anime4K_AutoDownscalePre_x4.glsl",
            "Restore/Anime4K_Restore_CNN_M.glsl",
            "Upscale/Anime4K_Upscale_CNN_x2_M.glsl",
        ]),
    ]
}

struct HideOverlayModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.persistentSystemOverlays(.hidden)
        } else {
            content
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
