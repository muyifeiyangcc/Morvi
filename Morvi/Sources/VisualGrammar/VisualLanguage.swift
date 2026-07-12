import SwiftUI
import UIKit

enum VisualLanguage {
    static let ink = Color.black.opacity(0.96)
    static let softInk = Color.black.opacity(0.62)
    static let faintInk = Color.black.opacity(0.38)
    static let lime = Color(red: 0.82, green: 1.0, blue: 0.22)
    static let mint = Color(red: 0.86, green: 0.99, blue: 1.0)
    static let lineGreen = Color(red: 0.65, green: 0.84, blue: 0.25)
    static let quietFill = Color(red: 0.83, green: 1.0, blue: 0.23).opacity(0.3)
    static let panelFill = Color.white
    static let charcoal = Color(red: 0.02, green: 0.04, blue: 0.03)

    static var themeGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 235.0 / 255.0, green: 254.0 / 255.0, blue: 175.0 / 255.0), Color(red: 224.0 / 255.0, green: 251.0 / 255.0, blue: 252.0 / 255.0)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var verticalThemeGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 1.0, green: 0.94, blue: 0.43), Color(red: 1.0, green: 0.94, blue: 0.43).opacity(0.0)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

enum TextCraft {
    static func source(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(sourceName(for: weight), size: size)
    }

    static func one(_ size: CGFloat) -> Font {
        Font.custom("FredokaOne-Regular", size: size)
    }

    private static func sourceName(for weight: Font.Weight) -> String {
        switch weight {
        case .medium, .semibold:
            return "SourceHanSansSC-Medium"
        case .bold, .heavy, .black:
            return "SourceHanSansSC-Bold"
        case .light, .ultraLight, .thin:
            return "SourceHanSansSC-Light"
        default:
            return "SourceHanSansSC-Regular"
        }
    }
}

struct AmbientBackdrop: View {
    var includesBottomTint = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                if includesBottomTint {
                    LinearGradient(
                        colors: [Color.white, VisualLanguage.mint.opacity(0.52)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    Color.white
                }
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.89, green: 1.0, blue: 0.47), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: proxy.size.width * 0.8
                        )
                    )
                    .frame(width: proxy.size.width * 1.6, height: proxy.size.width * 1.6)
                    .position(x: proxy.size.width * 0.1, y: 0)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.87, green: 0.98, blue: 1.0), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: proxy.size.width * 0.6
                        )
                    )
                    .frame(width: proxy.size.width * 1.2, height: proxy.size.width * 1.2)
                    .position(x: proxy.size.width * 0.9, y: 0)
            }
            .ignoresSafeArea()
        }
    }
}

struct TopChromeView: View {
    let title: String
    var showsBack = false
    var trailingAsset: String?
    var backAction: (() -> Void)?
    var trailingAction: (() -> Void)?

    var body: some View {
        GeometryReader { proxy in
            let statusBarHeight = max(proxy.safeAreaInsets.top, chromeHeight - 76)
            HStack(spacing: 16) {
                if showsBack {
                    Button(action: { backAction?() }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 58, height: 58)
                            .background(Circle().fill(Color.white.opacity(0.85)))
                    }
                    .buttonStyle(.plain)
                }
                Text(title)
                    .font(TextCraft.one(30))
                    .foregroundColor(.black)
                Spacer()
                if let trailingAsset {
                    Button(action: { trailingAction?() }) {
                        Image(trailingAsset)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 58, height: 58)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, statusBarHeight + 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .frame(height: statusBarHeight + 76, alignment: .top)
        }
        .frame(height: chromeHeight)
    }

    private var chromeHeight: CGFloat {
        let topInset = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top ?? 44
        return topInset + 76
    }
}

struct FloatingRailView: View {
    @Binding var selected: RailSection
    let requestSelection: (RailSection) -> Void

    var body: some View {
        HStack {
            ForEach(RailSection.allCases) { section in
                Button(action: { requestSelection(section) }) {
                    ZStack {
                        if section == selected {
                            Circle()
                                .fill(Color(red: 0.78, green: 1.0, blue: 0.42))
                                .overlay(Circle().stroke(Color.black, lineWidth: 3))
                                .frame(width: 65, height: 65)
                        }
                        Image(section == selected ? section.selectedAssetName : section.assetName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: section == selected ? 65 : 45, height: section == selected ? 65 : 45)
                            .clipShape(Circle())
                            .opacity(section == selected ? 1 : 0.9)
                    }
                    .frame(width: 65, height: 65)
                }
                .buttonStyle(.plain)
                if section != RailSection.allCases.last {
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 5.5)
        .frame(height: 76)
        .background(
            Capsule()
                .fill(VisualLanguage.charcoal)
                .shadow(color: .black.opacity(0.20), radius: 14, x: 0, y: 6)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
    }
}

struct LowerShadowButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TextCraft.one(16))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.39, green: 0.68, blue: 0.02))
                            .offset(y: 3)
                        RoundedRectangle(cornerRadius: 12)
                            .fill(VisualLanguage.themeGradient)
                    }
                )
        }
        .buttonStyle(.plain)
    }
}

struct DashedWritingBox: View {
    @Binding var text: String
    let placeholder: String
    var minHeight: CGFloat = 96

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(VisualLanguage.quietFill)
            RoundedRectangle(cornerRadius: 8)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundColor(VisualLanguage.lineGreen)
            ClearWritingSurface(value: $text)
                .padding(8)
            if text.isEmpty {
                Text(placeholder)
                    .font(TextCraft.source(14))
                    .foregroundColor(VisualLanguage.faintInk)
                    .padding(.top, 16)
                    .padding(.leading, 16)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: minHeight)
    }
}

private struct ClearWritingSurface: UIViewRepresentable {
    @Binding var value: String

    func makeUIView(context: Context) -> UITextView {
        let writingView = UITextView()
        writingView.delegate = context.coordinator
        writingView.backgroundColor = .clear
        writingView.textColor = .black
        writingView.font = UIFont(name: "SourceHanSansSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
        writingView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        writingView.textContainer.lineFragmentPadding = 0
        writingView.autocorrectionType = .no
        writingView.autocapitalizationType = .none
        writingView.spellCheckingType = .no
        writingView.smartDashesType = .no
        writingView.smartQuotesType = .no
        writingView.smartInsertDeleteType = .no
        return writingView
    }

    func updateUIView(_ writingView: UITextView, context: Context) {
        if writingView.text != value {
            writingView.text = value
        }
    }

    func makeCoordinator() -> WritingCoordinator {
        WritingCoordinator(value: $value)
    }

    final class WritingCoordinator: NSObject, UITextViewDelegate {
        @Binding private var value: String

        init(value: Binding<String>) {
            _value = value
        }

        func textViewDidChange(_ textView: UITextView) {
            value = textView.text
        }
    }
}

struct SoftNoticeView: View {
    let text: String
    var completion: (() -> Void)?

    @State private var isPresented = false
    @State private var isDismissing = false

    var body: some View {
        Text(text)
            .font(TextCraft.source(15, weight: .medium))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 26)
            .padding(.top, 14)
            .padding(.bottom, 16)
            .frame(minHeight: 54)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.thinMaterial)
                        .environment(\.colorScheme, .dark)
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.04, green: 0.05, blue: 0.04).opacity(0.94),
                                    Color(red: 0.08, green: 0.14, blue: 0.12).opacity(0.92)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(red: 0.80, green: 1.0, blue: 0.30).opacity(0.65), lineWidth: 1)
                }
            )
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        Color(red: 0.78, green: 1.0, blue: 0.24),
                        Color(red: 0.87, green: 0.98, blue: 1.0).opacity(0.95)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 3)
                .clipShape(Capsule())
                .padding(.horizontal, 14)
                .padding(.bottom, 5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.30), radius: 22, x: 0, y: 10)
            .padding(.horizontal, 28)
            .opacity(isPresented && isDismissing == false ? 1 : 0)
            .scaleEffect(isPresented ? (isDismissing ? 0.98 : 1) : 0.96)
            .offset(y: isPresented ? (isDismissing ? -6 : 0) : 8)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: 0.20)) {
                    isPresented = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeIn(duration: 0.22)) {
                        isDismissing = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        completion?()
                    }
                }
            }
    }
}

struct ProgressVeilView: View {
    @State private var ringRotation: Double = 0
    @State private var faceScale: CGFloat = 1

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.72)
                    .stroke(
                        Color(red: 0.82, green: 1.0, blue: 0.24),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(ringRotation))
                LoadingFaceView()
                    .frame(width: 48, height: 48)
                    .scaleEffect(faceScale)
            }
            .frame(width: 116, height: 96)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .onTapGesture {}
        .onAppear {
            ringRotation = 0
            withAnimation(.linear(duration: 0.95).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
            withAnimation(.easeInOut(duration: 0.72).repeatForever(autoreverses: true)) {
                faceScale = 0.94
            }
        }
    }
}

private struct LoadingFaceView: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.82, green: 1.0, blue: 0.24))
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(red: 0.04, green: 0.05, blue: 0.04))
                .frame(width: 8, height: 14)
                .offset(x: 15, y: 15)
            Text("<")
                .font(TextCraft.source(22, weight: .bold))
                .foregroundColor(Color(red: 0.04, green: 0.05, blue: 0.04))
                .offset(x: 29, y: 4)
            LoadingSmileShape()
                .stroke(
                    Color(red: 0.04, green: 0.05, blue: 0.04),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
        }
    }
}

private struct LoadingSmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 17, y: 33))
        path.addQuadCurve(
            to: CGPoint(x: 34, y: 30),
            control: CGPoint(x: 25, y: 39)
        )
        return path
    }
}

struct EmptyListArtworkView: View {
    let title: String

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(VisualLanguage.themeGradient)
                    .frame(width: 96, height: 96)
                    .opacity(0.55)
                Image(systemName: "sparkles")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundColor(.gray)
            }
            Text(title)
                .font(TextCraft.source(16, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

struct GlassPanel<Content: View>: View {
    let cornerRadius: CGFloat
    @ViewBuilder var content: Content

    init(cornerRadius: CGFloat = 28, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .background(.ultraThinMaterial)
            .background(Color.white.opacity(0.28))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

struct AvatarBadgeView: View {
    let assetName: String
    var size: CGFloat = 56

    var body: some View {
        Group {
            if let portrait = IdentityArchive.shared.portrait(named: assetName) {
                Image(uiImage: portrait)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .background(Circle().fill(Color.gray.opacity(0.18)))
    }
}

extension View {
    func plainEntryBehavior() -> some View {
        self
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
    }
}
