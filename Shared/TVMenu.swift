//
//  TVMenu.swift
//  Anime4KMetal
//
//  Created by Yi Xie on 2023/03/26.
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
