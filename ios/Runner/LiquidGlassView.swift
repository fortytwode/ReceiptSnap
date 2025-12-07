import Flutter
import UIKit

// MARK: - Liquid Glass Platform View Factory
class LiquidGlassViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return LiquidGlassPlatformView(frame: frame, viewIdentifier: viewId, arguments: args, messenger: messenger)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

// MARK: - Liquid Glass Platform View
class LiquidGlassPlatformView: NSObject, FlutterPlatformView {
    private var liquidGlassView: UIView

    init(frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, messenger: FlutterBinaryMessenger) {
        liquidGlassView = LiquidGlassUIView(frame: frame)
        super.init()
    }

    func view() -> UIView {
        return liquidGlassView
    }
}

// MARK: - Liquid Glass UI View
class LiquidGlassUIView: UIView {
    private var blurView: UIVisualEffectView?
    private var gradientLayer: CAGradientLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        // Create a subtle gradient background
        gradientLayer = CAGradientLayer()
        gradientLayer?.colors = [
            UIColor(red: 0.4, green: 0.494, blue: 0.918, alpha: 0.3).cgColor,
            UIColor(red: 0.463, green: 0.294, blue: 0.635, alpha: 0.3).cgColor,
            UIColor(red: 0.941, green: 0.576, blue: 0.984, alpha: 0.3).cgColor
        ]
        gradientLayer?.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer?.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer?.frame = bounds

        if let gradientLayer = gradientLayer {
            layer.addSublayer(gradientLayer)
        }

        // Add blur effect for glass appearance
        // Using .systemMaterial for a modern glass-like effect
        if #available(iOS 13.0, *) {
            let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
            blurView = UIVisualEffectView(effect: blurEffect)
            blurView?.frame = bounds
            blurView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            blurView?.alpha = 0.6

            if let blurView = blurView {
                addSubview(blurView)
            }
        } else {
            // Fallback for older iOS versions
            let blurEffect = UIBlurEffect(style: .light)
            blurView = UIVisualEffectView(effect: blurEffect)
            blurView?.frame = bounds
            blurView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]

            if let blurView = blurView {
                addSubview(blurView)
            }
        }

        // Add subtle shimmer animation
        addShimmerEffect()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer?.frame = bounds
        blurView?.frame = bounds
    }

    private func addShimmerEffect() {
        // Create a shimmer layer
        let shimmerLayer = CAGradientLayer()
        shimmerLayer.colors = [
            UIColor.white.withAlphaComponent(0).cgColor,
            UIColor.white.withAlphaComponent(0.2).cgColor,
            UIColor.white.withAlphaComponent(0).cgColor
        ]
        shimmerLayer.startPoint = CGPoint(x: 0, y: 0.5)
        shimmerLayer.endPoint = CGPoint(x: 1, y: 0.5)
        shimmerLayer.frame = CGRect(x: -bounds.width, y: 0, width: bounds.width * 2, height: bounds.height)

        layer.addSublayer(shimmerLayer)

        // Animate the shimmer
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = -bounds.width
        animation.toValue = bounds.width
        animation.duration = 3.0
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        shimmerLayer.add(animation, forKey: "shimmer")
    }
}

// MARK: - Plugin Registration
class LiquidGlassPlugin {
    static func register(with registrar: FlutterPluginRegistrar) {
        let factory = LiquidGlassViewFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: "liquid_glass_view")
    }
}
