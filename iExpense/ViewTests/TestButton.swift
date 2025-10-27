//
//  TestButton.swift
//  Inpenso
//
//  Created by Dragomir Mindrescu on 16.10.2025.
//

import SwiftUI

struct TestButton: View {
    var body: some View {
        Button(action: {
            print("hello")
        }) {
            Text("press")
        }
        
        Button("Hello") {
            print("test")
        }
        .font(.headline)
        .foregroundColor(.white)
        .padding()
        .background(Color.blue)
        .cornerRadius(10)
//        .disabled(true)
        
        if #available(iOS 26.0, *) {
            Button("here"){}
                .buttonStyle(.glass)
        } else {
            // Fallback on earlier versions
        }
        if #available(iOS 26.0, *) {
            Button("here"){}
                .buttonStyle(.glass)
            
        } else {
            // Fallback on earlier versions
        }
        
        if #available(iOS 26.0, *) {
            Group {
                Link(
                    "App Designer2",
                    destination: URL(string: "https://reddit.com/u/App-Designer2")!
                )
                
                Button("Tap Me", action: {})
                    .buttonStyle(.glass)
            }
            .padding()
        } else {
            // Fallback on earlier versions
        }
        
        Button(action: {
            print("test")
        }) {
            if #available(iOS 26.0, *) {
                Text("Hello, World!")
                    .font(.title)
                    .padding()
                    .glassEffect(.regular.tint(.orange).interactive())
            }
        }
        
        if #available(iOS 26.0, *) {
            Button(action: {
                // Use NotificationCenter to notify MainTabView to switch to expenses tab
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToExpensesTab"), object: nil)
            }) {
                Text("View All Expenses")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.top, 8)
            }
            .buttonStyle(.glass)
        } else {
            Button(action: {
                // Use NotificationCenter to notify MainTabView to switch to expenses tab
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToExpensesTab"), object: nil)
            }) {
                Text("View All Expenses")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentColor, lineWidth: 1.5)
                    )
                    .padding(.top, 8)
            }
        }
        
        Button(action: {
            NotificationCenter.default.post(name: NSNotification.Name("SwitchToExpensesTab"), object: nil)
        }) {
            Text("View All Expenses")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.top, 8)
        }

    }
}

#Preview {
    TestButton()
}
