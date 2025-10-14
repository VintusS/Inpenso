//
//  SegmentedControlView.swift
//  Inpenso
//
//  Created by Dragomir Mindrescu on 14.10.2025.
//

import SwiftUI

struct SegmentedControlView: View {
    @State private var favoriteColor = 0

    var body: some View {
        VStack {
            Picker("What is your favorite color?", selection: $favoriteColor) {
                Text("Red").tag(0)
                Text("Green").tag(1)
                Text("Blue").tag(2)
            }
            .pickerStyle(.segmented)

            Text("Value: \(favoriteColor)")
        }
    }
}

#Preview {
    SegmentedControlView()
}
