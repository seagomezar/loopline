import StoreKit
import SwiftUI

@MainActor
struct LooplinePaywallView: View {
    @ObservedObject var model: LooplineViewModel
    let trigger: LooplinePaywallTrigger
    @State private var selectedProductID: String = LooplineStoreService.lifetimeProductID

    private var store: LooplineStoreService { model.storeService }

    var body: some View {
        LooplineScreenBackground {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    headerBar
                    heroCard
                    featuresCard
                    pricingSection
                    primaryActionSection
                    if trigger.isFromExportAttempt && model.tracks.count <= LooplineStoreService.freeMaxTracks {
                        freeExportFallbackButton
                    }
                    statusBanner
                    legalFooter
                }
                .padding(20)
            }
        }
        .task {
            await store.loadProducts()
        }
    }

    private var headerBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 3) {
                ForEach([Color.looplineBlue, .looplineCoral, .looplineGold, .looplineMint].indices, id: \.self) { index in
                    Capsule()
                        .fill([Color.looplineBlue, .looplineCoral, .looplineGold, .looplineMint][index])
                        .frame(width: 4.5, height: [11.0, 20.0, 14.0, 23.0][index])
                }
            }
            Text("loopline pro")
                .font(LooplineTheme.text(20, weight: .bold))
                .tracking(-0.6)
            LooplinePill(text: "100% On-Device", tint: .looplineMint, icon: "internaldrive")
            Spacer()
            Button {
                model.dismissPaywall()
            } label: {
                Image(systemName: "xmark")
                    .font(LooplineTheme.text(13, weight: .bold))
                    .foregroundStyle(Color.looplineInk)
                    .frame(width: 34, height: 34)
                    .background(Color.looplineSurface, in: Circle())
                    .overlay { Circle().stroke(Color.looplineLine, lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("paywall.close")
            .accessibilityLabel("Close Loopline Pro")
        }
    }

    private var heroCard: some View {
        LooplineSurface(padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text(trigger.eyebrow)
                    .font(LooplineTheme.text(10, weight: .bold, mono: true))
                    .foregroundStyle(Color.looplineBlue)
                Text(trigger.headline)
                    .font(LooplineTheme.text(26, weight: .bold))
                    .tracking(-0.8)
                    .fixedSize(horizontal: false, vertical: true)
                Text(trigger.subtitle)
                    .font(LooplineTheme.text(13))
                    .foregroundStyle(Color.looplineMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var featuresCard: some View {
        LooplineSurface(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Everything in Loopline Pro")
                        .font(LooplineTheme.text(16, weight: .bold))
                    Spacer()
                    Text("FREE VS PRO")
                        .font(LooplineTheme.text(9, weight: .bold, mono: true))
                        .foregroundStyle(Color.looplineMuted)
                }

                featureRow(
                    icon: "person.3.sequence.fill",
                    tint: .looplineBlue,
                    title: "4 to 6+ Voices per Arrangement",
                    detail: "Free includes up to 3 voices. Pro unlocks full quartets, quintets, and sextets."
                )
                Divider()
                featureRow(
                    icon: "rectangle.3.group.fill",
                    tint: .looplineCoral,
                    title: "All 16 Collage & Asymmetric Layouts",
                    detail: "Unlock Frames 40/60, Diptic 60/40, Center Stage, Hero splits, and 3×N / 4×N grids."
                )
                Divider()
                featureRow(
                    icon: "4k.tv.fill",
                    tint: .looplineGold,
                    title: "4K UHD & HEVC (.mov / .mp4) Export",
                    detail: "Render crisp 2160×3840 masters and space-saving HEVC files alongside 1080p H.264."
                )
                Divider()
                featureRow(
                    icon: "sparkles.rectangle.stack.fill",
                    tint: .looplineMint,
                    title: "Clean Video — No Watermark",
                    detail: "Remove the subtle \"Made with Loopline\" corner badge on every exported video."
                )
                Divider()
                featureRow(
                    icon: "wand.and.stars",
                    tint: .looplineBlue,
                    title: "Unlimited Automatic Sync Assist",
                    detail: "One-tap millisecond alignment with confidence scoring across all your takes."
                )
                Divider()
                featureRow(
                    icon: "folder.fill.badge.plus",
                    tint: .looplineCoral,
                    title: "Unlimited Local Sessions",
                    detail: "Save and manage as many multi-track sessions as your iPhone or iPad storage holds."
                )
            }
        }
    }

    private func featureRow(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(LooplineTheme.text(16, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(LooplineTheme.text(14, weight: .bold))
                Text(detail)
                    .font(LooplineTheme.text(12))
                    .foregroundStyle(Color.looplineMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                selectedProductID = LooplineStoreService.lifetimeProductID
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: selectedProductID == LooplineStoreService.lifetimeProductID ? "checkmark.circle.fill" : "circle")
                        .font(LooplineTheme.text(20, weight: .bold))
                        .foregroundStyle(Color.looplineBlue)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Loopline Pro — Lifetime Unlock")
                                .font(LooplineTheme.text(15, weight: .bold))
                            Text("OWN FOREVER")
                                .font(LooplineTheme.text(8, weight: .bold, mono: true))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.looplinePastelGreen, in: Capsule())
                        }
                        Text("Pay once. Yours forever on iPhone & iPad with Family Sharing.")
                            .font(LooplineTheme.text(11))
                            .foregroundStyle(Color.looplineMuted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(store.lifetimeDisplayPrice)
                            .font(LooplineTheme.text(18, weight: .bold, mono: true))
                        Text("one-time")
                            .font(LooplineTheme.text(10, mono: true))
                            .foregroundStyle(Color.looplineMuted)
                    }
                }
                .padding(16)
                .background(
                    selectedProductID == LooplineStoreService.lifetimeProductID ? Color.looplinePastelBlue.opacity(0.45) : Color.looplineSurface,
                    in: RoundedRectangle(cornerRadius: 18)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            selectedProductID == LooplineStoreService.lifetimeProductID ? Color.looplineBlue : Color.looplineLine,
                            lineWidth: selectedProductID == LooplineStoreService.lifetimeProductID ? 2 : 1
                        )
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("paywall.option.lifetime")

            if let annual = store.annualProduct {
                Button {
                    selectedProductID = annual.id
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selectedProductID == annual.id ? "checkmark.circle.fill" : "circle")
                            .font(LooplineTheme.text(20, weight: .bold))
                            .foregroundStyle(Color.looplineBlue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(annual.displayName.isEmpty ? "Loopline Pro — Annual Pass" : annual.displayName)
                                .font(LooplineTheme.text(15, weight: .bold))
                            Text("Auto-renews yearly unless canceled at least 24 hours before renewal.")
                                .font(LooplineTheme.text(11))
                                .foregroundStyle(Color.looplineMuted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(annual.displayPrice)
                                .font(LooplineTheme.text(16, weight: .bold, mono: true))
                            Text("/ year")
                                .font(LooplineTheme.text(10, mono: true))
                                .foregroundStyle(Color.looplineMuted)
                        }
                    }
                    .padding(16)
                    .background(
                        selectedProductID == annual.id ? Color.looplinePastelBlue.opacity(0.45) : Color.looplineSurface,
                        in: RoundedRectangle(cornerRadius: 18)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                selectedProductID == annual.id ? Color.looplineBlue : Color.looplineLine,
                                lineWidth: selectedProductID == annual.id ? 2 : 1
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("paywall.option.annual")
            }
        }
    }

    private var primaryActionSection: some View {
        VStack(spacing: 10) {
            LooplinePrimaryButton(
                title: store.isPurchasing ? "Processing…" : "Unlock Loopline Pro · \(selectedPriceLabel)",
                icon: "lock.open.fill",
                tint: .looplineHalftoneBlue,
                isDisabled: store.isPurchasing
            ) {
                Task {
                    await handlePurchaseTap()
                }
            }
            .accessibilityIdentifier("paywall.purchase")

            #if DEBUG && targetEnvironment(simulator)
            if store.products.isEmpty {
                Button {
                    store.setDebugProUnlocked(true)
                    model.completePendingProActionAfterUnlock(for: trigger)
                } label: {
                    Text("Simulator Preview: Unlock Pro Immediately")
                        .font(LooplineTheme.text(12, weight: .bold, mono: true))
                        .foregroundStyle(Color.looplineBlue)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(Color.looplineSurface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.looplineBlue.opacity(0.4), lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("paywall.simulatorUnlock")
            }
            #endif
        }
    }

    private var freeExportFallbackButton: some View {
        Button {
            model.exportWithFreeDefaults()
        } label: {
            VStack(spacing: 3) {
                Text("Continue with Free Export")
                    .font(LooplineTheme.text(14, weight: .bold))
                    .foregroundStyle(Color.looplineInk)
                Text("1080p H.264 MP4 · Classic frame layout · With \"Made with Loopline\" badge")
                    .font(LooplineTheme.text(11, mono: true))
                    .foregroundStyle(Color.looplineMuted)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.looplineSurface, in: RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).stroke(Color.looplineLine, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("paywall.continueFreeExport")
    }

    @ViewBuilder
    private var statusBanner: some View {
        if let status = store.statusMessage {
            LooplineSurface(padding: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.looplineBlue)
                    Text(status)
                        .font(LooplineTheme.text(12, weight: .medium))
                }
            }
        }
        if let err = store.errorMessage {
            LooplineSurface(padding: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.looplineCoral)
                    Text(err)
                        .font(LooplineTheme.text(12, weight: .medium))
                }
            }
        }
    }

    private var legalFooter: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    let restored = await store.restorePurchases()
                    if restored {
                        model.completePendingProActionAfterUnlock(for: trigger)
                    }
                }
            } label: {
                Label("Restore Purchases", systemImage: "arrow.clockwise")
                    .font(LooplineTheme.text(13, weight: .bold))
                    .foregroundStyle(Color.looplineInk)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.looplineSurface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.looplineLine, lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .disabled(store.isPurchasing)
            .accessibilityIdentifier("paywall.restore")

            HStack(spacing: 16) {
                Link("Terms of Use (EULA)", destination: LooplineStoreService.termsOfUseURL)
                    .accessibilityIdentifier("paywall.termsLink")
                Text("·").foregroundStyle(Color.looplineMuted)
                Link("Privacy Policy", destination: LooplineStoreService.privacyPolicyURL)
                    .accessibilityIdentifier("paywall.privacyLink")
                Text("·").foregroundStyle(Color.looplineMuted)
                Link("Support", destination: LooplineStoreService.supportURL)
                    .accessibilityIdentifier("paywall.supportLink")
            }
            .font(LooplineTheme.text(11, weight: .medium))
            .tint(.looplineBlue)

            Text("Purchases are processed securely by Apple via StoreKit 2 and verified locally on your device. No account sign-in or cloud connection is required.")
                .font(LooplineTheme.text(10, mono: true))
                .foregroundStyle(Color.looplineMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var selectedPriceLabel: String {
        if selectedProductID == LooplineStoreService.annualProductID, let annual = store.annualProduct {
            return annual.displayPrice
        }
        return store.lifetimeDisplayPrice
    }

    private func handlePurchaseTap() async {
        if selectedProductID == LooplineStoreService.annualProductID, let annual = store.annualProduct {
            let unlocked = await store.purchase(annual)
            if unlocked {
                model.completePendingProActionAfterUnlock(for: trigger)
            }
            return
        }
        if let lifetime = store.lifetimeProduct {
            let unlocked = await store.purchase(lifetime)
            if unlocked {
                model.completePendingProActionAfterUnlock(for: trigger)
            }
        } else {
            await store.loadProducts()
            if let lifetime = store.lifetimeProduct {
                let unlocked = await store.purchase(lifetime)
                if unlocked {
                    model.completePendingProActionAfterUnlock(for: trigger)
                }
            } else {
                store.statusMessage = "App Store products are being prepared. Please check your connection or use Restore Purchases."
            }
        }
    }
}
