import SwiftUI
import QuartzCore

/// Where an upload currently is. SwiftUI owns this value; the layer work below
/// only reacts to it.
enum UploadPhase: Equatable {
    case idle
    case uploading(Double)
    case succeeded
    case failed
}

/// A circular upload indicator built out of shape layers.
///
/// The view's own backing layer is the unfilled track, so the ring needs no
/// container view of its own. The stroke that fills, the checkmark and the
/// percentage readout sit on top of it as sublayers, because sublayers always
/// composite above their host layer's own content.
final class RingView: UIView {

    override class var layerClass: AnyClass { CAShapeLayer.self }
    private var trackLayer: CAShapeLayer { layer as! CAShapeLayer }

    private let progressLayer = CAShapeLayer()
    private let checkLayer = CAShapeLayer()
    private let percentLayer = CATextLayer()

    /// Called once the animation for a terminal phase has finished playing,
    /// driven by a transaction completion block rather than a guessed delay.
    var onSettled: (() -> Void)?

    private var lastPhase: UploadPhase?
    private let lineWidth: CGFloat = 12

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        trackLayer.fillColor = nil
        trackLayer.lineWidth = lineWidth

        progressLayer.fillColor = nil
        progressLayer.lineWidth = lineWidth
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0

        checkLayer.fillColor = nil
        checkLayer.lineWidth = lineWidth * 0.85
        checkLayer.lineCap = .round
        checkLayer.lineJoin = .round
        checkLayer.strokeEnd = 0

        percentLayer.alignmentMode = .center
        percentLayer.fontSize = 30
        percentLayer.string = "0%"

        layer.addSublayer(progressLayer)
        layer.addSublayer(checkLayer)
        layer.addSublayer(percentLayer)

        refreshColors()

        // A CGColor is a snapshot of a resolved colour, so it does not follow
        // the interface style the way a UIColor on a view would. Re-resolving
        // on a trait change is the fix.
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: Self, _) in
            view.refreshColors()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        // `path`, `bounds` and `frame` are all implicitly animatable on a
        // standalone layer. Without the transaction below, every resize would
        // morph the ring over a quarter of a second instead of just redrawing it.
        withoutActions {
            let radius = (min(bounds.width, bounds.height) - lineWidth) / 2
            let ring = UIBezierPath(
                arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
                radius: max(radius, 0),
                startAngle: -.pi / 2,
                endAngle: 1.5 * .pi,
                clockwise: true
            )

            trackLayer.path = ring.cgPath

            progressLayer.frame = bounds
            progressLayer.path = ring.cgPath

            checkLayer.frame = bounds
            checkLayer.path = checkmarkPath().cgPath

            // A CATextLayer left at the default contentsScale of 1.0 rasterises
            // at one pixel per point and looks soft on every shipping device.
            percentLayer.contentsScale = traitCollection.displayScale
            percentLayer.frame = CGRect(x: 0, y: bounds.midY - 20, width: bounds.width, height: 40)
        }
    }

    private func checkmarkPath() -> UIBezierPath {
        let w = bounds.width, h = bounds.height
        let path = UIBezierPath()
        path.move(to: CGPoint(x: w * 0.30, y: h * 0.52))
        path.addLine(to: CGPoint(x: w * 0.44, y: h * 0.66))
        path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.35))
        return path
    }

    // MARK: - Phases

    func apply(_ phase: UploadPhase, animated: Bool) {
        defer { lastPhase = phase }

        switch phase {
        case .idle:
            guard lastPhase != .idle else { return }
            reset()

        case .uploading(let fraction):
            var wasUploading = false
            if let lastPhase, case .uploading = lastPhase { wasUploading = true }
            if !wasUploading { reset() }
            setProgress(fraction, animated: animated)

        case .succeeded:
            guard lastPhase != .succeeded else { return }
            finishSuccessfully()

        case .failed:
            guard lastPhase != .failed else { return }
            finishWithFailure()
        }
    }

    private func setProgress(_ fraction: Double, animated: Bool) {
        let target = CGFloat(min(max(fraction, 0), 1))

        // Changing a text layer's string implicitly cross-fades its contents.
        // Pleasant once, mush when it happens five times a second.
        withoutActions { percentLayer.string = "\(Int((target * 100).rounded()))%" }

        guard animated else {
            withoutActions { progressLayer.strokeEnd = target }
            return
        }

        // Start from what is on screen right now rather than from the model
        // value. That is the difference between a progress bar that interrupts
        // smoothly and one that jumps backwards on every update.
        let current = progressLayer.presentation()?.strokeEnd ?? progressLayer.strokeEnd
        withoutActions { progressLayer.strokeEnd = target }

        let fill = CABasicAnimation(keyPath: "strokeEnd")
        fill.fromValue = current
        fill.toValue = target
        fill.duration = 0.3
        fill.timingFunction = CAMediaTimingFunction(name: .easeOut)
        progressLayer.add(fill, forKey: "progress")
    }

    private func finishSuccessfully() {
        withoutActions { percentLayer.opacity = 0 }

        let close = CABasicAnimation(keyPath: "strokeEnd")
        close.fromValue = progressLayer.presentation()?.strokeEnd ?? progressLayer.strokeEnd
        close.toValue = 1
        close.duration = 0.2
        close.timingFunction = CAMediaTimingFunction(name: .easeOut)
        withoutActions { progressLayer.strokeEnd = 1 }
        progressLayer.add(close, forKey: "progress")

        let draw = CABasicAnimation(keyPath: "strokeEnd")
        draw.fromValue = 0
        draw.toValue = 1
        draw.duration = 0.35
        draw.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0, 0.2, 1)
        // beginTime shifts the checkmark until after the ring closes, and
        // .backwards pins it to its from-value in the meantime. No dispatch
        // after, no second timer to keep in sync.
        draw.beginTime = CACurrentMediaTime() + 0.2
        draw.fillMode = .backwards

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in self?.onSettled?() }
        withoutActions { checkLayer.strokeEnd = 1 }
        checkLayer.add(draw, forKey: "draw")
        CATransaction.commit()
    }

    private func finishWithFailure() {
        withoutActions {
            progressLayer.strokeColor = UIColor.systemRed.cgColor
            percentLayer.foregroundColor = UIColor.systemRed.cgColor
            percentLayer.string = "Failed"
        }

        // position.x is a key path into a struct-valued property. Core Animation
        // resolves it for you; there is no separate x property to animate.
        let origin = layer.position.x
        let shake = CAKeyframeAnimation(keyPath: "position.x")
        shake.values = [0, -11, 9, -6, 3, 0].map { origin + $0 }
        shake.keyTimes = [0, 0.15, 0.35, 0.55, 0.8, 1]
        shake.duration = 0.45
        shake.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in self?.onSettled?() }
        layer.add(shake, forKey: "shake")
        CATransaction.commit()
    }

    private func reset() {
        progressLayer.removeAllAnimations()
        checkLayer.removeAllAnimations()
        layer.removeAllAnimations()

        withoutActions {
            progressLayer.strokeEnd = 0
            checkLayer.strokeEnd = 0
            percentLayer.opacity = 1
            percentLayer.string = "0%"
        }
        refreshColors()
    }

    // MARK: - Helpers

    private func refreshColors() {
        let failed = lastPhase == .failed
        withoutActions {
            trackLayer.strokeColor = UIColor.systemFill.cgColor
            progressLayer.strokeColor = (failed ? UIColor.systemRed : UIColor.systemBlue).cgColor
            checkLayer.strokeColor = UIColor.systemGreen.cgColor
            percentLayer.foregroundColor = (failed ? UIColor.systemRed : UIColor.label).cgColor
        }
    }

    private func withoutActions(_ body: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        body()
        CATransaction.commit()
    }
}

/// Bridges the layer-backed ring into SwiftUI.
struct ProgressRing: UIViewRepresentable {
    let phase: UploadPhase
    var onSettled: (() -> Void)?

    func makeUIView(context: Context) -> RingView {
        let view = RingView(frame: .zero)
        view.apply(phase, animated: false)
        return view
    }

    func updateUIView(_ view: RingView, context: Context) {
        view.onSettled = onSettled
        view.apply(phase, animated: true)
    }
}
