import SwiftUI

struct CustomButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isDestructive: Bool = false
    var isDisabled: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(Constants.Layout.defaultCornerRadius)
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .disabled(isDisabled)
    }
    
    private var backgroundColor: Color {
        if isDestructive {
            return .red
        }
        return Constants.Colors.appAccent
    }
    
    private var foregroundColor: Color {
        if isDestructive {
            return .white
        }
        return .white
    }
}

#Preview {
    VStack(spacing: 20) {
        CustomButton(
            title: "Default Button",
            icon: "plus",
            action: {}
        )
        
        CustomButton(
            title: "Destructive Button",
            icon: "trash",
            action: {},
            isDestructive: true
        )
        
        CustomButton(
            title: "Disabled Button",
            icon: "lock",
            action: {},
            isDisabled: true
        )
    }
    .padding()
} 