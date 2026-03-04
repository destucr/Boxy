import SwiftUI

struct NoAnimationButtonStyle: ButtonStyle {
    let baseBackground: String
    let baseIcon: String
    let altIcon: String?
    let isActive: Bool
    let size: CGFloat
    func makeBody(configuration: Configuration) -> some View {
        let isPressedOrActive = configuration.isPressed || isActive
        let currentIcon = (configuration.isPressed && altIcon != nil) ? altIcon! : baseIcon
        return ZStack {
            Image(isPressedOrActive ? "button_disable" : baseBackground)
                .resizable()
                .frame(width: size, height: size * 0.6)
            Image(currentIcon)
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.35, height: size * 0.35)
        }
    }
}

struct PlainNoAnimationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(nil, value: configuration.isPressed)
    }
}

struct RubberButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0) // Squish effect
            .opacity(configuration.isPressed ? 0.9 : 1.0) // Slight compression darkening
            .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.5), value: configuration.isPressed)
    }
}
