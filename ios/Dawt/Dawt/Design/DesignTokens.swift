import SwiftUI

enum DawtColor {
    static let blush = Color(red: 0.98, green: 0.93, blue: 0.94)
    static let mist = Color(red: 0.94, green: 0.96, blue: 0.97)
    static let rose = Color(red: 0.86, green: 0.33, blue: 0.45)
    static let roseDeep = Color(red: 0.72, green: 0.22, blue: 0.36)
    static let ink = Color(red: 0.16, green: 0.14, blue: 0.18)
    static let inkMuted = Color(red: 0.42, green: 0.38, blue: 0.42)
    static let fertile = Color(red: 0.25, green: 0.55, blue: 0.58)
    static let ovulation = Color(red: 0.20, green: 0.45, blue: 0.52)
    static let period = Color(red: 0.86, green: 0.33, blue: 0.45)
    static let card = Color.white.opacity(0.78)
}

enum DawtType {
    /// Yellowtail (Google Fonts, OFL) — brand wordmark only.
    static func brand(_ size: CGFloat) -> Font {
        .custom("Yellowtail-Regular", size: size)
    }

    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func body(_ size: CGFloat = 16, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

struct DawtBrandTitle: View {
    var size: CGFloat = 34
    var color: Color = DawtColor.ink

    var body: some View {
        // SwiftUI.Text clips Yellowtail’s overflowing t-swash; UILabel does not when sized for ink.
        DawtBrandWordmarkLabel(text: "Dawt", size: size, color: UIColor(color))
            .fixedSize()
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel("Dawt")
    }
}

/// Yellowtail’s final `t` paints ~0.25em past its advance; size the label to fit the ink.
private struct DawtBrandWordmarkLabel: UIViewRepresentable {
    var text: String
    var size: CGFloat
    var color: UIColor

    func makeUIView(context: Context) -> BrandInkLabel {
        let label = BrandInkLabel()
        label.textAlignment = .left
        label.clipsToBounds = false
        label.lineBreakMode = .byClipping
        label.backgroundColor = .clear
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }

    func updateUIView(_ label: BrandInkLabel, context: Context) {
        label.text = text
        label.font = UIFont(name: "Yellowtail-Regular", size: size) ?? .systemFont(ofSize: size)
        label.textColor = color
        // Measured from Yellowtail-Regular: "Dawt" ink extends ~0.24em past advance on the right.
        label.inkPadding = UIEdgeInsets(
            top: size * 0.08,
            left: size * 0.06,
            bottom: size * 0.12,
            right: size * 0.40
        )
        label.invalidateIntrinsicContentSize()
    }
}

private final class BrandInkLabel: UILabel {
    var inkPadding: UIEdgeInsets = .zero

    override var intrinsicContentSize: CGSize {
        let base = super.intrinsicContentSize
        guard base.width < CGFloat.greatestFiniteMagnitude / 2 else { return base }
        return CGSize(
            width: base.width + inkPadding.left + inkPadding.right,
            height: base.height + inkPadding.top + inkPadding.bottom
        )
    }

    override func drawText(in rect: CGRect) {
        // Keep the right pad inside the draw rect so the t-swash isn’t clipped.
        super.drawText(
            in: rect.inset(
                by: UIEdgeInsets(
                    top: inkPadding.top,
                    left: inkPadding.left,
                    bottom: inkPadding.bottom,
                    right: 0
                )
            )
        )
    }
}

struct DawtBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                DawtColor.blush,
                DawtColor.mist,
                Color(red: 0.99, green: 0.96, blue: 0.95)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct DawtCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(DawtColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
            )
    }
}

extension View {
    func dawtCard() -> some View {
        modifier(DawtCardModifier())
    }
}
