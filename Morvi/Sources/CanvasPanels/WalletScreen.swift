import SwiftUI

struct WalletScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accessStore: AccessSessionStore
    @EnvironmentObject private var experienceStore: ExperienceContainer

    var body: some View {
        VStack(spacing: 0) {
            TopChromeView(title: "Wallet", showsBack: true, backAction: { dismiss() })
            ScrollView {
                VStack(spacing: 10) {
                    balanceCard
                        .padding(.top, 16)
                    ForEach(experienceStore.creditCatalog) { pack in
                        CreditPackRow(pack: pack) {
                            experienceStore.acquireStoredValue(pack, accessStore: accessStore)
                        }
                    }
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 40)
            }
        }
        .background(AmbientBackdrop())
        .onAppear { experienceStore.refreshCreditBalance(for: accessStore) }
    }

    private var balanceCard: some View {
        ZStack(alignment: .trailing) {
            NotchedBlackShape()
                .fill(VisualLanguage.charcoal)
                .frame(height: 122)
            VStack(alignment: .leading, spacing: 8) {
                Text("My balance")
                    .font(TextCraft.source(20, weight: .medium))
                    .foregroundColor(.white)
                Text("\(experienceStore.creditBalance)")
                    .font(TextCraft.one(36))
                    .foregroundColor(VisualLanguage.lime)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 21)
            Image("balance_gem_mark")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 182)
                .offset(x: -14, y: -30)
        }
    }
}

private struct CreditPackRow: View {
    let pack: CreditPackRecord
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image("value_item_crystal_mark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 36)
                Text(pack.amountText)
                    .font(TextCraft.source(24, weight: .medium))
                    .foregroundColor(.black)
                Spacer()
                Text(pack.priceText)
                    .font(TextCraft.source(20))
                    .foregroundColor(.black.opacity(0.8))
                    .overlay(alignment: .bottom) {
                        LinearGradient(colors: [Color(red: 0.72, green: 0.94, blue: 0.31), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(height: 4)
                            .offset(y: 3)
                    }
            }
            .padding(.horizontal, 16)
            .frame(height: 68)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }
}

private struct NotchedBlackShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius: CGFloat = 14
        let notchShift: CGFloat = 40
        path.move(to: CGPoint(x: radius, y: 0))
        path.addLine(to: CGPoint(x: rect.width * 0.48 + notchShift, y: 0))
        path.addQuadCurve(to: CGPoint(x: rect.width * 0.58 + notchShift, y: 20), control: CGPoint(x: rect.width * 0.53 + notchShift, y: 0))
        path.addLine(to: CGPoint(x: rect.width - radius, y: 20))
        path.addQuadCurve(to: CGPoint(x: rect.width, y: 20 + radius), control: CGPoint(x: rect.width, y: 20))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - radius))
        path.addQuadCurve(to: CGPoint(x: rect.width - radius, y: rect.height), control: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: radius, y: rect.height))
        path.addQuadCurve(to: CGPoint(x: 0, y: rect.height - radius), control: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: radius))
        path.addQuadCurve(to: CGPoint(x: radius, y: 0), control: CGPoint(x: 0, y: 0))
        return path
    }
}
