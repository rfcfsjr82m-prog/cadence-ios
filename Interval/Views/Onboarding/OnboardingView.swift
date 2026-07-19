import SwiftUI
import AVFoundation

// MARK: - Onboarding
//
// Six slides shown once on first launch, before RootView's library.
// A single panoramic backdrop pans left as the user advances, revealing
// more of the image on every slide.
//
//   0  Welcome        — wordmark + positioning
//   1  Cues           — interactive: try sounds, haptics, light
//   2  Pillars        — multi-select Mind / Body / Productivity
//   3  Presets        — presets for the selected pillars, free forever
//   4  Programs       — the three built-in progressive programs
//   5  Paywall        — Pro card, free-tier explanation, PaywallSheet

struct OnboardingView: View {
    var onFinished: () -> Void

    @State private var page = 0
    @State private var forward = true
    @State private var selectedPillars: Set<Category> = []
    @State private var showPaywall = false
    @State private var colorBurst: Color? = nil
    @State private var infoProgram: TrainingProtocol? = nil
    @State private var voicePlayer: AVAudioPlayer? = nil
    @State private var infoPreset: TimerConfig? = nil

    private let pageCount = 6

    var body: some View {
        ZStack {
            backdrop

            // Legibility scrim over the photo
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.45), location: 0.0),
                    .init(color: .black.opacity(0.25), location: 0.35),
                    .init(color: .black.opacity(0.72), location: 1.0),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            slideContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Color-burst demo overlay (cue slide)
            if let burst = colorBurst {
                burst.opacity(0.55)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            topBar
        }
        .background(Color.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    if value.translation.width < -40 { advance() }
                    else if value.translation.width > 40 { goBack() }
                }
        )
        .sheet(isPresented: $showPaywall) {
            PaywallSheet(onPurchased: { finish() })
        }
        .onChange(of: showPaywall) { _, showing in
            // Came back from the paywall as a Pro user → done.
            if !showing && StoreManager.shared.isPro { finish() }
        }
        .onAppear {
            SoundEngine.shared.preload(cues: [.beeps, .gong, .sonarPing, .boxingBell])
        }
    }

    // MARK: - Backdrop

    /// The panoramic backdrop, scaled to fill the screen height. It pans left
    /// as `page` increases, revealing more of the image on every slide.
    private var backdrop: some View {
        GeometryReader { geo in
            // Backdrop asset is 1797 × 875 — scale to fill the screen height.
            let imageWidth = geo.size.height * (1797.0 / 875.0)
            let progress = pageCount > 1 ? CGFloat(page) / CGFloat(pageCount - 1) : 0
            let maxShift = max(0, imageWidth - geo.size.width)

            Image("OnboardingBackdrop")
                .resizable()
                .frame(width: imageWidth, height: geo.size.height)
                .offset(x: -progress * maxShift)
                .animation(.easeInOut(duration: 0.5), value: page)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
                .clipped()
        }
        .ignoresSafeArea()
    }

    // MARK: - Top bar (back · dots · skip)

    private var topBar: some View {
        VStack {
            HStack {
                if page > 0 {
                    CircleIconButton(systemName: "chevron.left") { goBack() }
                } else {
                    Color.clear.frame(width: 40, height: 40)
                }

                Spacer()

                dots

                Spacer()

                CircleIconButton(systemName: "xmark") { finish() }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()
        }
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(0..<pageCount, id: \.self) { i in
                Capsule()
                    .fill(Color.white.opacity(i == page ? 0.95 : 0.35))
                    .frame(width: i == page ? 22 : 7, height: 7)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: page)
    }

    // MARK: - Slides

    @ViewBuilder
    private var slideContent: some View {
        ZStack {
            Group {
                switch page {
                case 0:  welcomeSlide
                case 1:  cuesSlide
                case 2:  pillarsSlide
                case 3:  presetsSlide
                case 4:  programsSlide
                default: paywallSlide
                }
            }
            .id(page)
            .transition(.asymmetric(
                insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
        }
        .animation(.easeInOut(duration: 0.4), value: page)
    }

    // ── Slide 0 · Welcome ────────────────────────────────────────────────────

    private var welcomeSlide: some View {
        ZStack {
            // Dead-center of the screen: positioning lines + social proof,
            // treated as one centered group.
            VStack(spacing: 0) {
                Text(NSLocalizedString("Designed to disappear — and to get you in the flow", comment: "Onboarding welcome eyebrow"))
                    .font(.system(size: 22, weight: .bold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(NSLocalizedString("The only interval timer you will need", comment: "Onboarding welcome subline"))
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)

                reviewQuote
                    .padding(.top, 76)
            }
            .padding(.horizontal, 36)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            VStack(spacing: 0) {
                Text(verbatim: "CADENCE")
                    .font(.system(size: 32, weight: .semibold))
                    .tracking(10)
                    .foregroundStyle(.white)
                    .padding(.leading, 10)   // optically balance the tracking
                    .padding(.top, 68)

                Text(NSLocalizedString("One timer for training, breathwork, meditation, and deep focus.", comment: "Onboarding welcome headline"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 20)

                Spacer()

                primaryButton(NSLocalizedString("Get Started", comment: "Onboarding CTA")) { advance() }
                    .padding(.bottom, 24)
            }
        }
    }

    /// Social proof: a real App Store review, set quietly — no card, just
    /// stars, the quote, and a name.
    private var reviewQuote: some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.yellow.opacity(0.9))
                }
            }

            Text("“" + NSLocalizedString("Finally an interval timer that covers many areas of life. Love the unique features like using a flashlight or vibration as a cue.", comment: "Onboarding welcome review quote") + "”")
                .font(.system(size: 14).italic())
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Text(verbatim: "— Chris")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // ── Slide 1 · Pillars ────────────────────────────────────────────────────

    private var pillarsSlide: some View {
        ZStack {
            // Dead-center of the screen: the pillar cards.
            VStack(spacing: 12) {
                pillarCard(.mind, icon: "brain.head.profile",
                           benefit: NSLocalizedString("Breathwork, meditation & wind-down", comment: "Onboarding pillar benefit"))
                pillarCard(.physical, icon: "figure.run",
                           benefit: NSLocalizedString("HIIT, Tabata, running & cold exposure", comment: "Onboarding pillar benefit"))
                pillarCard(.productivity, icon: "timer",
                           benefit: NSLocalizedString("Deep work, Pomodoro & reading", comment: "Onboarding pillar benefit"))
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            VStack(spacing: 0) {
                slideHeader(
                    title: NSLocalizedString("What do you practice?", comment: "Onboarding pillars title"),
                    subtitle: NSLocalizedString("Choose one or more — Cadence covers them all.", comment: "Onboarding pillars subtitle"))

                Spacer()

                primaryButton(NSLocalizedString("Continue", comment: "Onboarding CTA"),
                              disabled: selectedPillars.isEmpty) { advance() }
                    .padding(.bottom, 24)
            }
        }
    }

    private func pillarCard(_ category: Category, icon: String, benefit: String) -> some View {
        let isSelected = selectedPillars.contains(category)
        return Button {
            HapticEngine.shared.fire(.softPulse)
            withAnimation(.easeInOut(duration: 0.18)) {
                if isSelected { selectedPillars.remove(category) }
                else { selectedPillars.insert(category) }
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white : .white.opacity(0.8))
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(category.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(benefit)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Color.white : .white.opacity(0.35))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial)
                    if isSelected {
                        RoundedRectangle(cornerRadius: 18).fill(Color.accent.opacity(0.45))
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(isSelected ? Color.white.opacity(0.9) : .white.opacity(0.14),
                                  lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // ── Slide 2 · Presets ────────────────────────────────────────────────────

    /// Presets grouped by the pillars picked on the previous slide.
    /// 3 per group; 6 when only one pillar is selected. `hasMore` is true only
    /// when the library really holds more presets than shown for that group.
    private var presetGroups: [(category: Category, presets: [TimerConfig], hasMore: Bool)] {
        let pillars = selectedPillars.isEmpty ? Set(Category.allCases) : selectedPillars
        let limit = pillars.count == 1 ? 6 : 3
        return Category.allCases
            .filter { pillars.contains($0) }
            .map { category in
                let all = Presets.all.filter { $0.category == category }
                return (category, Array(all.prefix(limit)), all.count > limit)
            }
            .filter { !$0.1.isEmpty }
    }

    private var presetsSlide: some View {
        VStack(spacing: 0) {
            slideHeader(
                title: NSLocalizedString("Presets for your practice", comment: "Onboarding presets title"),
                subtitle: NSLocalizedString("Ready to start — and free forever.", comment: "Onboarding presets subtitle"))

            let groups = presetGroups
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(groups, id: \.category) { group in
                        if groups.count > 1 {
                            Text(group.category.displayName)
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(1.2)
                                .textCase(.uppercase)
                                .foregroundStyle(.white.opacity(0.55))
                                .padding(.top, group.category == groups.first?.category ? 0 : 14)
                        }
                        ForEach(group.presets) { preset in
                            presetRow(preset)
                        }
                        if group.hasMore {
                            Text(NSLocalizedString("More in the library", comment: "Onboarding presets more hint"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding(.trailing, 4)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 22)
            }
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black, location: 0.07),
                        .init(color: .black, location: 0.93),
                        .init(color: .clear, location: 1.0),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .padding(.top, 10)

            primaryButton(NSLocalizedString("Continue", comment: "Onboarding CTA")) { advance() }
                .padding(.top, 8)
                .padding(.bottom, 24)
        }
        .sheet(item: $infoPreset) { preset in
            VStack(alignment: .leading, spacing: 12) {
                Text(verbatim: preset.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(verbatim: NSLocalizedString(preset.description, comment: ""))
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textSecondary)
                    .lineSpacing(3)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .presentationDetents([.height(200)])
            .presentationBackground(Color.surface)
            .presentationDragIndicator(.visible)
        }
    }

    private func presetRow(_ preset: TimerConfig) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(preset.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                blockStrip(preset)
                    .frame(height: 4)
                    .clipShape(Capsule())
            }

            Spacer()

            Text("\(max(1, preset.totalDurationSeconds / 60)) min")
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.6))

            if !preset.description.isEmpty {
                Button {
                    infoPreset = preset
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func blockStrip(_ preset: TimerConfig) -> some View {
        GeometryReader { geo in
            let total = max(1, preset.blocks.reduce(0) { $0 + $1.durationSeconds })
            HStack(spacing: 2) {
                ForEach(preset.blocks) { block in
                    block.color.color
                        .frame(width: max(3, geo.size.width * CGFloat(block.durationSeconds) / CGFloat(total)))
                }
            }
        }
    }

    // ── Slide 3 · Cues ───────────────────────────────────────────────────────

    private var cuesSlide: some View {
        VStack(spacing: 0) {
            slideHeader(
                title: NSLocalizedString("Sound, haptics & light", comment: "Onboarding cues title"),
                subtitle: NSLocalizedString("Customize your own timers with cues like these and many more — try them:", comment: "Onboarding cues subtitle"))

            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    cueGroup(NSLocalizedString("Sound", comment: "Onboarding cue group")) {
                        cueChip("Beeps")       { SoundEngine.shared.play(.beeps) }
                        cueChip("Gong")        { SoundEngine.shared.play(.gong) }
                        cueChip("Sonar Ping")  { SoundEngine.shared.play(.sonarPing) }
                        cueChip("Boxing Bell") { SoundEngine.shared.play(.boxingBell) }
                    }
                    moreInAppCaption
                }

                VStack(alignment: .leading, spacing: 10) {
                    cueGroup(NSLocalizedString("Haptics", comment: "Onboarding cue group")) {
                        cueChip(HapticCue.softPulse.displayName) { HapticEngine.shared.fire(.softPulse) }
                        cueChip(HapticCue.doubleTap.displayName) { HapticEngine.shared.fire(.doubleTap) }
                        cueChip(HapticCue.longBuzz.displayName)  { HapticEngine.shared.fire(.longBuzz) }
                    }
                    moreInAppCaption
                }

                VStack(alignment: .leading, spacing: 10) {
                    cueGroup(NSLocalizedString("Light", comment: "Onboarding cue group")) {
                        cueChip(NSLocalizedString("Color burst", comment: "Onboarding light cue")) { fireColorBurst() }
                        cueChip(NSLocalizedString("Flashlight", comment: "")) { FlashlightEngine.shared.preview() }
                    }
                    moreInAppCaption
                }

                VStack(alignment: .leading, spacing: 10) {
                    cueGroup(NSLocalizedString("Voice", comment: "Onboarding cue group")) {
                        cueChip(NSLocalizedString("Female", comment: "Voice preview chip")) { playVoiceSample("Voice_Female_Start_2") }
                        cueChip(NSLocalizedString("Male", comment: "Voice preview chip"))   { playVoiceSample("Voice_Male_Finish_6") }
                    }
                    Text(NSLocalizedString("A voice can mark the beginning and end of a practice.", comment: "Onboarding voice caption"))
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)

            Spacer()

            primaryButton(NSLocalizedString("Continue", comment: "Onboarding CTA")) { advance() }
                .padding(.bottom, 24)
        }
    }

    private func playVoiceSample(_ resource: String) {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "mp3") else { return }
        voicePlayer = try? AVAudioPlayer(contentsOf: url)
        voicePlayer?.play()
    }

    private var moreInAppCaption: some View {
        Text(NSLocalizedString("…and some more in the app.", comment: "Onboarding cues footer"))
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.55))
    }

    private func cueGroup(_ title: String, @ViewBuilder chips: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.55))

            HStack(spacing: 8) { chips() }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func cueChip(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func fireColorBurst() {
        withAnimation(.easeIn(duration: 0.08)) { colorBurst = .blockTeal }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeOut(duration: 0.45)) { colorBurst = nil }
        }
    }

    // ── Slide 4 · Programs ───────────────────────────────────────────────────

    private var programsSlide: some View {
        ZStack {
            // Dead-center of the screen: the program cards.
            VStack(spacing: 12) {
                ForEach(TrainingProtocols.all) { program in
                    programRow(program)
                }
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            VStack(spacing: 0) {
                slideHeader(
                    title: NSLocalizedString("Programs that grow with you.", comment: "Onboarding programs title"),
                    subtitle: NSLocalizedString("Structured plans that help you progress — session by session. Check them out:", comment: "Onboarding programs subtitle"))

                Spacer()

                primaryButton(NSLocalizedString("Continue", comment: "Onboarding CTA")) { advance() }
                    .padding(.bottom, 24)
            }
        }
        .sheet(item: $infoProgram) { program in
            VStack(alignment: .leading, spacing: 12) {
                Text(verbatim: program.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(verbatim: program.description)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textSecondary)
                    .lineSpacing(3)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .presentationDetents([.height(200)])
            .presentationBackground(Color.surface)
            .presentationDragIndicator(.visible)
        }
    }

    private func programRow(_ program: TrainingProtocol) -> some View {
        Button {
            infoProgram = program
        } label: {
            HStack(spacing: 14) {
                Image(systemName: programIcon(program))
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(program.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(programBenefit(program))
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Text(String(format: NSLocalizedString("%d units", comment: "Program unit count"), program.units.count))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.12), in: Capsule())

                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func programIcon(_ program: TrainingProtocol) -> String {
        switch program.category {
        case .physical:     return "figure.run"
        case .productivity: return "book"
        case .mind:         return program.name.localizedCaseInsensitiveContains("read") ? "book" : "leaf"
        }
    }

    private func programBenefit(_ program: TrainingProtocol) -> String {
        if program.name.localizedCaseInsensitiveContains("5k") {
            return NSLocalizedString("From run/walk intervals to your first 5K", comment: "Onboarding program benefit")
        } else if program.name.localizedCaseInsensitiveContains("read") {
            return NSLocalizedString("Read longer, without interruption", comment: "Onboarding program benefit")
        } else {
            return NSLocalizedString("From 5 quiet minutes to 30", comment: "Onboarding program benefit")
        }
    }

    // ── Slide 5 · Paywall ────────────────────────────────────────────────────

    private var paywallSlide: some View {
        VStack(spacing: 0) {
            Text(NSLocalizedString("One more thing", comment: "Onboarding paywall title"))
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 76)

            Spacer()

            VStack(spacing: 18) {
                HStack(spacing: 8) {
                    Text(verbatim: "Cadence")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(verbatim: "PRO")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(.white, in: Capsule())
                }

                VStack(alignment: .leading, spacing: 11) {
                    paywallBullet(NSLocalizedString("Unlimited custom timers", comment: "Onboarding paywall bullet"))
                    paywallBullet(NSLocalizedString("Every program, every unit", comment: "Onboarding paywall bullet"))
                    paywallBullet(NSLocalizedString("7-day free trial with the annual plan", comment: "Onboarding paywall bullet"))
                }

                Text(NSLocalizedString("Your first 2 runs of custom timers & programs are free — and all presets stay free forever.", comment: "Onboarding paywall footnote"))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                Button {
                    showPaywall = true
                } label: {
                    Text(NSLocalizedString("Discover Pro", comment: "Onboarding paywall CTA"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    finish()
                } label: {
                    Text(NSLocalizedString("Not now", comment: "Onboarding paywall dismiss"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(.white.opacity(0.16), lineWidth: 1)
            )
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }

    private func paywallBullet(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.9))
            Spacer(minLength: 0)
        }
    }

    // MARK: - Shared pieces

    private func slideHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .padding(.top, 76)
    }

    private func primaryButton(_ title: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.white, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .padding(.horizontal, 24)
    }

    // MARK: - Navigation

    private func advance() {
        guard page < pageCount - 1 else { return }
        if page == 2 && selectedPillars.isEmpty { return }
        forward = true
        withAnimation { page += 1 }
    }

    private func goBack() {
        guard page > 0 else { return }
        forward = false
        withAnimation { page -= 1 }
    }

    private func finish() {
        onFinished()
    }
}

// MARK: - Circle icon button (back / close)

private struct CircleIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
