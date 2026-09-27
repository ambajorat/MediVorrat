import SwiftUI

// Palette 1:1 aus „Blase & Darm Manager“ (AppColors.swift) –
// Dunkel + Orange, im Hellmodus Leinenton.
extension Color {
    static let accent = Color(light: .init(red: 0.85, green: 0.53, blue: 0.18),
                              dark: .init(red: 0.91, green: 0.57, blue: 0.23))

    static let pageBg = Color(light: .init(red: 0.97, green: 0.96, blue: 0.94),
                              dark: .init(red: 0.08, green: 0.08, blue: 0.08))

    static let cardBg = Color(light: .white,
                              dark: .init(red: 0.13, green: 0.13, blue: 0.13))

    static let subtleText = Color(light: .init(red: 0.45, green: 0.43, blue: 0.40),
                                  dark: .init(red: 0.60, green: 0.58, blue: 0.55))

    static let pillBg = Color(light: .init(red: 0.92, green: 0.91, blue: 0.89),
                              dark: .init(red: 0.18, green: 0.18, blue: 0.17))

    static let pillBorder = Color(light: .init(red: 0.80, green: 0.78, blue: 0.75),
                                  dark: .init(red: 0.35, green: 0.33, blue: 0.30))

    static let pillActiveBg = accent

    static let pillActiveText = Color(light: .white,
                                      dark: .init(red: 0.08, green: 0.08, blue: 0.08))

    // Statusfarben, abgestimmt auf die BDM-Palette
    static let statusRed = Color(light: .init(red: 0.72, green: 0.24, blue: 0.20),
                                 dark: .init(red: 0.90, green: 0.38, blue: 0.32))
    static let statusOk = Color(light: .init(red: 0.16, green: 0.52, blue: 0.50),
                                dark: .init(red: 0.35, green: 0.72, blue: 0.68))
    static let statusOrdered = Color(light: .init(red: 0.55, green: 0.40, blue: 0.70),
                                     dark: .init(red: 0.70, green: 0.55, blue: 0.85))
}

extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

/// Großer Knopf wie in BDM (LargeButtonStyle)
struct LargeButtonStyle: ButtonStyle {
    var color: Color = .accent
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(configuration.isPressed ? color.opacity(0.8) : color, in: .rect(cornerRadius: 12))
            .foregroundStyle(Color.pillActiveText)
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Kartenrahmen wie die BDM-Karten
extension View {
    func card(padding: CGFloat = 14) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBg, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.pillBorder, lineWidth: 0.5))
    }

    /// Formulare auf Seitenhintergrund legen
    func pageForm() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color.pageBg)
    }
}
