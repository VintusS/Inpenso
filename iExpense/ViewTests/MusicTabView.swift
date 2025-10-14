//
//  MusicTabView.swift
//  Inpenso
//
//  Created by Dragomir Mindrescu on 14.10.2025.
//

import SwiftUI

struct MusicTabView: View {
    @Binding var searchText: String

    var body: some View {
        if #available(iOS 26.0, *) {
            TabView {
                Tab("Home", systemImage: "house") {
                    Text("Home")
                }
                Tab("New", systemImage: "squareshape.split.2x2") {
                    Text("New")
                }
                Tab("Radio", systemImage: "dot.radiowaves.left.and.right") {
                    Text("Radio")
                }
                Tab("Library", systemImage: "music.note.tv") {
                    Text("Library")
                }
                Tab("Search", systemImage: "magnifyingglass", role: .search) {
                    NavigationStack {
                        
                    }
                }
            }.searchable(text: $searchText)
                .tabBarMinimizeBehavior(.onScrollDown)
                .tabViewBottomAccessory {
                    HStack {
                        Spacer().frame(width: 20)
                        Image(systemName: "command.square")
                        Text(".tabViewBottomAccessory")
                        Spacer()
                        Image(systemName: "play.fill")
                        Image(systemName: "forward.fill")
                        Spacer().frame(width: 20)
                    }
                }
        } else {
            // Fallback on earlier versions
        }
    }
}

#Preview {
    MusicTabView(searchText: .constant("Test"))
}
