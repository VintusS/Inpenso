import SwiftUI

/// An expandable date picker with toggle functionality
struct DatePickerCard: View {
    let title: String
    @Binding var selectedDate: Date
    @Binding var isExpanded: Bool
    var maxDate: Date = Date()
    var dateRange: ClosedRange<Date>? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
            
            VStack {
                // Date display button
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.accentColor)
                        
                        Text(formattedDate())
                            .font(.headline)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                            .rotationEffect(Angle(degrees: isExpanded ? 180 : 0))
                    }
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                // Expandable date picker
                if isExpanded {
                    if let range = dateRange {
                        DatePicker("", selection: $selectedDate, in: range, displayedComponents: .date)
                            .datePickerStyle(GraphicalDatePickerStyle())
                            .labelsHidden()
                            .padding(.horizontal)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .onChange(of: selectedDate) { _ in
                                HapticFeedback.selection()
                            }
                    } else {
                        DatePicker("", selection: $selectedDate, in: ...maxDate, displayedComponents: .date)
                            .datePickerStyle(GraphicalDatePickerStyle())
                            .labelsHidden()
                            .padding(.horizontal)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .onChange(of: selectedDate) { _ in
                                HapticFeedback.selection()
                            }
                    }
                }
            }
            .padding(.bottom, 12)
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: selectedDate)
    }
}

#Preview {
    VStack(spacing: 20) {
        DatePickerCard(
            title: "Date",
            selectedDate: .constant(Date()),
            isExpanded: .constant(false)
        )
        
        DatePickerCard(
            title: "Date (Expanded)",
            selectedDate: .constant(Date()),
            isExpanded: .constant(true)
        )
    }
    .padding()
} 