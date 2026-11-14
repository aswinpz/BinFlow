import SwiftUI

// MARK: - Glowing center scan button (for the tab bar)
struct CXGlowScanButton: View {
    var icon: String = "qrcode.viewfinder"
    var action: () -> Void
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.35))
                    .frame(width: 64, height: 64)
                    .scaleEffect(pulse ? 1.45 : 1)
                    .opacity(pulse ? 0 : 0.8)
                Circle()
                    .fill(Theme.mintGradient)
                    .frame(width: 64, height: 64)
                    .shadow(color: Theme.accent.opacity(0.6), radius: 14)
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, isActive: !reduceMotion)
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = true }
        }
    }
}

// MARK: - Staggered appearance for rows and cards
struct CXStaggerIn: ViewModifier {
    let index: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .onAppear {
                withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.06)) {
                    shown = true
                }
            }
    }
}

extension View {
    func staggerIn(_ index: Int) -> some View { modifier(CXStaggerIn(index: index)) }
}

// MARK: - Quantity stepper with a rolling number
struct CXQuantityStepper: View {
    @Binding var quantity: Int

    var body: some View {
        HStack(spacing: 28) {
            Button { if quantity > 0 { quantity -= 1 } } label: {
                Image(systemName: "minus")
                    .frame(width: 44, height: 44)
                    .background(Theme.cardSubtle, in: Circle())
            }
            Text("\(quantity)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .contentTransition(.numericText(value: Double(quantity)))
                .animation(.spring(response: 0.3), value: quantity)
                .frame(minWidth: 60)
            Button { quantity += 1 } label: {
                Image(systemName: "plus")
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44)
                    .background(Theme.accent, in: Circle())
                    .shadow(color: Theme.accent.opacity(0.5), radius: 8)
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: quantity)
    }
}

// MARK: - Capacity bar that fills on appear
struct CXCapacityBar: View {
    let used: Int
    let total: Int
    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule()
                    .fill(Theme.mintGradient)
                    .frame(width: geo.size.width * progress)
                    .shadow(color: Theme.accent.opacity(0.5), radius: 6)
            }
        }
        .frame(height: 6)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) {
                progress = CGFloat(used) / CGFloat(max(total, 1))
            }
        }
        .onChange(of: used) { _, new in
            withAnimation(.spring(response: 0.5)) {
                progress = CGFloat(new) / CGFloat(max(total, 1))
            }
        }
    }
}
