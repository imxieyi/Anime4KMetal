// Copyright 2023 Yi Xie
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

struct TVMenu: View {
    let title: String
    let count: Int
    let getLabel: (Int) -> String
    let action: (Int) -> Void
    
    var body: some View {
        NavigationLink {
            TVMenuList(count: count, getLabel: getLabel, action: action)
        } label: {
            Text(title)
        }
    }
}

struct TVMenuList: View {
    @Environment(\.dismiss) private var dismiss
    
    let count: Int
    let getLabel: (Int) -> String
    let action: (Int) -> Void
    
    var body: some View {
        List {
            ForEach(0..<count, id: \.self) { i in
                Button {
                    action(i)
                    dismiss()
                } label: {
                    Text(getLabel(i))
                }
            }
        }
    }
}
