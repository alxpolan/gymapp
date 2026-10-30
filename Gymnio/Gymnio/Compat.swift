import SwiftUI
import Charts

// Backports so the app runs on iOS 16+ while newer systems keep the newer look and APIs.

@available(iOS 26, *)
private func makeGlass(tint: Color?, interactive: Bool) -> Glass {
    var glass = Glass.regular
    if let tint { glass = glass.tint(tint) }
    if interactive { glass = glass.interactive() }
    return glass
}

extension View {

    /// `onChange(of:)` with the single-parameter closure: the two-parameter form needs iOS 17.
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, _ action: @escaping (V) -> Void) -> some View {
        if #available(iOS 17, *) {
            self.onChange(of: value) { _, newValue in action(newValue) }
        } else {
            self.onChange(of: value, perform: action)
        }
    }

    /// Liquid Glass on iOS 26+, a material with a hairline border before that.
    @ViewBuilder
    func glassSurface<S: Shape>(_ shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(makeGlass(tint: tint, interactive: interactive), in: shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.fill(tint ?? .clear))
                .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
        }
    }

    /// Chart scrubbing: native selection on iOS 17+, a drag gesture on iOS 16.
    @ViewBuilder
    func chartSelectionCompat(_ selection: Binding<Int?>) -> some View {
        if #available(iOS 17, *) {
            self.chartXSelection(value: selection)
        } else {
            self.chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { drag in
                                    let origin = geo[proxy.plotAreaFrame].origin
                                    if let index: Int = proxy.value(atX: drag.location.x - origin.x) {
                                        selection.wrappedValue = index
                                    }
                                }
                                .onEnded { _ in selection.wrappedValue = nil }
                        )
                }
            }
        }
    }
}

// MARK: - SF Symbols that only exist on newer systems

enum SymbolCompat {
    /// `clock.arrow.trianglehead.counterclockwise.rotate.90` needs iOS 18.
    static var history: String {
        if #available(iOS 18, *) { return "clock.arrow.trianglehead.counterclockwise.rotate.90" }
        return "clock.arrow.circlepath"
    }

    /// `figure.strengthtraining.traditional` needs iOS 17.
    static var strength: String {
        if #available(iOS 17, *) { return "figure.strengthtraining.traditional" }
        return "dumbbell.fill"
    }
}
