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
            
            VStack(spacing: 0) {
                // Date display button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
                
                // Reserved space for date picker with clipping
                ZStack(alignment: .top) {
                    // Empty container for space
                    Color.clear
                        .frame(height: isExpanded ? (UIDevice.current.userInterfaceIdiom == .pad ? 400 : 300) : 0)
                    
                    // Date picker
                    Group {
                        if let range = dateRange {
                            DatePicker("", selection: $selectedDate, in: range, displayedComponents: .date)
                                .datePickerStyle(GraphicalDatePickerStyle())
                                .labelsHidden()
                                .padding(.horizontal)
                                .onChange(of: selectedDate) {
                                    HapticFeedback.selection()
                                }
                        } else {
                            DatePicker("", selection: $selectedDate, in: ...maxDate, displayedComponents: .date)
                                .datePickerStyle(GraphicalDatePickerStyle())
                                .labelsHidden()
                                .padding(.horizontal)
                                .onChange(of: selectedDate) {
                                    HapticFeedback.selection()
                                }
                        }
                    }
                    .opacity(isExpanded ? 1 : 0)
                    .frame(height: isExpanded ? nil : 0, alignment: .top)
                }
                .clipped() // Clip content when collapsing
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
