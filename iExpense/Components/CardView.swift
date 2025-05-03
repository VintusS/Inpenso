import SwiftUI

/// A standard card view with consistent styling
struct CardView<Content: View>: View {
    let title: String
    let content: Content
    var titleAlignment: HorizontalAlignment = .leading
    var showDivider: Bool = false
    
    init(
        title: String,
        titleAlignment: HorizontalAlignment = .leading,
        showDivider: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.titleAlignment = titleAlignment
        self.showDivider = showDivider
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: titleAlignment, spacing: 12) {
            // Card title
            Text(title)
                .font(.headline)
                .padding(.horizontal)
            
            if showDivider {
                Divider()
                    .padding(.horizontal)
            }
            
            // Card content
            content
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

/// A standard section header text
struct SectionHeaderText: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundColor(.secondary)
    }
}

#Preview {
    VStack(spacing: 20) {
        CardView(title: "Basic Card") {
            Text("This is the content of the card")
                .padding()
        }
        
        CardView(title: "Card with Divider", showDivider: true) {
            VStack {
                Text("Above the divider")
                Text("Below the divider")
            }
            .padding()
        }
        
        CardView(title: "Card with List Content") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(1..<4) { i in
                    HStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 10, height: 10)
                        Text("Item \(i)")
                    }
                }
            }
            .padding()
        }
    }
    .padding()
} 