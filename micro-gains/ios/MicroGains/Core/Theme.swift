import UIKit

/// Every colour, font and metric in the app. SPEC "Look".
enum Theme {
    // MARK: Colour

    static let background = UIColor(named: "Background") ?? .black
    static let surface = UIColor(named: "Surface") ?? UIColor(red: 0x0E / 255, green: 0x14 / 255, blue: 0x11 / 255, alpha: 1)
    static let green = UIColor(named: "BrandGreen") ?? UIColor(red: 0x1F / 255, green: 0x7A / 255, blue: 0x3A / 255, alpha: 1)
    static let accent = UIColor(named: "AccentColor") ?? UIColor(red: 0x3D / 255, green: 0xDC / 255, blue: 0x6A / 255, alpha: 1)
    static let text = UIColor.white
    static let secondaryText = UIColor(named: "SecondaryText") ?? UIColor(red: 0x9B / 255, green: 0xA8 / 255, blue: 0xA0 / 255, alpha: 1)
    static let destructive = UIColor(named: "DestructiveRed") ?? UIColor.systemRed
    static let separator = UIColor(white: 1, alpha: 0.08)

    // MARK: Metrics

    static let cornerRadius: CGFloat = 14
    static let buttonHeight: CGFloat = 56
    static let minimumTapTarget: CGFloat = 44
    static let sidePadding: CGFloat = 24

    // MARK: Type

    /// Rounded bold numerals. Scales with Dynamic Type but stops short of
    /// blowing the Set screen apart.
    static func numerals(_ size: CGFloat) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: .bold)
        let rounded = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
        let font = UIFont(descriptor: rounded, size: size)
        return UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: font, maximumPointSize: size * 1.3)
    }

    static func title(_ size: CGFloat = 34, weight: UIFont.Weight = .bold) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let rounded = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
        let font = UIFont(descriptor: rounded, size: size)
        return UIFontMetrics(forTextStyle: .title1).scaledFont(for: font, maximumPointSize: size * 1.4)
    }

    static func body(_ size: CGFloat = 17, weight: UIFont.Weight = .regular) -> UIFont {
        UIFontMetrics(forTextStyle: .body).scaledFont(
            for: UIFont.systemFont(ofSize: size, weight: weight),
            maximumPointSize: size * 1.6
        )
    }

    static var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    // MARK: Builders

    static func label(
        _ text: String = "",
        font: UIFont,
        color: UIColor = Theme.text,
        alignment: NSTextAlignment = .natural
    ) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.textAlignment = alignment
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    static func primaryButton(_ title: String) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseBackgroundColor = Theme.green
        config.baseForegroundColor = .white
        config.cornerStyle = .fixed
        config.background.cornerRadius = Theme.cornerRadius
        config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.configurationUpdateHandler = { button in
            var config = button.configuration
            config?.attributedTitle = AttributedString(
                button.configuration?.title ?? "",
                attributes: AttributeContainer([.font: Theme.body(19, weight: .semibold)])
            )
            button.configuration = config
            button.alpha = button.isHighlighted ? 0.75 : 1
        }
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: Theme.buttonHeight).isActive = true
        return button
    }

    static func quietButton(_ title: String, color: UIColor = Theme.secondaryText) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = color
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.configurationUpdateHandler = { button in
            var config = button.configuration
            config?.attributedTitle = AttributedString(
                button.configuration?.title ?? "",
                attributes: AttributeContainer([.font: Theme.body(17, weight: .medium)])
            )
            button.configuration = config
            button.alpha = button.isHighlighted ? 0.6 : 1
        }
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: Theme.minimumTapTarget).isActive = true
        return button
    }

    static func card() -> UIView {
        let view = UIView()
        view.backgroundColor = Theme.surface
        view.layer.cornerRadius = Theme.cornerRadius
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    /// "2:15 PM" in the user's locale.
    static func timeString(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
