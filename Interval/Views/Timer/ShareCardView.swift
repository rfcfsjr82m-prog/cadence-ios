import SwiftUI
import PhotosUI
import Photos

// MARK: - Unsplash photo library

struct UnsplashPhoto: Identifiable {
    let id: Int
    let url: String
    let photographer: String
    let category: Category          // matches session category for auto-selection

    var thumbnailURL: String {
        url.replacingOccurrences(of: "w=774", with: "w=200")
    }
}

let unsplashPhotoLibrary: [UnsplashPhoto] = [
    // Mind
    UnsplashPhoto(id: 0, url: "https://images.unsplash.com/photo-1682556194247-fb9c5797eff9?q=80&w=774&auto=format&fit=crop", photographer: "Joshua Woroniecki", category: .mind),
    UnsplashPhoto(id: 1, url: "https://images.unsplash.com/photo-1682547095768-34acfee7860f?q=80&w=774&auto=format&fit=crop", photographer: "David Becker",          category: .mind),
    UnsplashPhoto(id: 2, url: "https://images.unsplash.com/photo-1682250648250-69c6a209b533?q=80&w=774&auto=format&fit=crop", photographer: "Mona Bernhardsen",      category: .mind),
    UnsplashPhoto(id: 3, url: "https://images.unsplash.com/photo-1646503802339-be7e08c048ff?q=80&w=774&auto=format&fit=crop", photographer: "Luiz Rogério Nunes",    category: .mind),
    UnsplashPhoto(id: 4, url: "https://images.unsplash.com/photo-1661850303006-513256095fe4?q=80&w=774&auto=format&fit=crop", photographer: "Klara Kulikova",        category: .mind),
    // Body
    UnsplashPhoto(id: 5, url: "https://images.unsplash.com/photo-1680724393406-67f4e03f135a?q=80&w=774&auto=format&fit=crop", photographer: "Klara Kulikova",        category: .physical),
    UnsplashPhoto(id: 6, url: "https://images.unsplash.com/photo-1633084002169-e2a5406ba0c7?q=80&w=774&auto=format&fit=crop", photographer: "Mathias Reding",        category: .physical),
    UnsplashPhoto(id: 7, url: "https://images.unsplash.com/photo-1634973510118-8ab6970a58ef?q=80&w=774&auto=format&fit=crop", photographer: "Milo Weiler",           category: .physical),
    UnsplashPhoto(id: 8, url: "https://images.unsplash.com/photo-1759674861540-afed9f86f94a?q=80&w=774&auto=format&fit=crop", photographer: "Pierre-Antoine Franck", category: .physical),
    // Productivity
    UnsplashPhoto(id: 9, url: "https://images.unsplash.com/photo-1559582284-9e0e40585af4?q=80&w=774&auto=format&fit=crop", photographer: "Nicolas Solerieu",         category: .productivity),
]

// MARK: - Photo library save helper
//
// nonisolated free function: the change block has NO actor isolation, so
// PHPhotoLibrary can call it freely on its own internal serial queue without
// triggering _dispatch_assert_queue_fail.

private func saveImageToPhotoLibrary(at url: URL) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
        }, completionHandler: { success, error in
            if success {
                continuation.resume()
            } else {
                continuation.resume(throwing: error ?? NSError(
                    domain: "CadencePhotoSave", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Could not save to Photos"]))
            }
        })
    }
}

// MARK: - Card layout styles

enum CardLayout: Int, CaseIterable {
    case classic  = 0   // Cadence/date top · rings center · strip+info bottom
    case centered = 1   // Everything center-aligned · strip as footer band
    case header   = 2   // Large title at top · rings + Cadence/Completed bar
}

// MARK: - Share card  (9:16 Instagram Story format)
//
// Background is a full-bleed photo dimmed by `backgroundDim`.
// The top and bottom text-area gradients are baked-in for legibility —
// the clear middle ring zone lets the photo breathe through.

struct ShareCard: View {
    let config: TimerConfig
    let title: String
    let startDate: Date
    let backgroundImage: UIImage?       // nil → dark gradient fallback
    let backgroundDim: Double           // 0 = no dim, 1 = fully black
    let photographerName: String?       // shown as credit if not nil
    let width: CGFloat
    let height: CGFloat                 // should be width × (16/9)
    var layout: CardLayout = .classic
    var locationPrefix: String = "in"   // "in" for area, "at" for venue
    var locationLabel: String? = nil    // nil → location row hidden

    // Proportional sizing
    private var hPad:     CGFloat { width  * 0.074 }
    private var topPad:   CGFloat { height * 0.055 }
    private var botPad:   CGFloat { height * 0.050 }
    private var metaSize: CGFloat { width  * 0.033 }
    private var catSize:  CGFloat { width  * 0.028 }
    private var ringSize: CGFloat { width  * 0.52  }
    private var strokeW:  CGFloat { ringSize * 0.065 }
    private var stripH:   CGFloat { max(4, height * 0.004) }
    private var nameSize: CGFloat { width  * 0.064 }
    private var radius:   CGFloat { width  * 0.048 }
    private var creditSize: CGFloat { width * 0.022 }

    // Tiny attribution line shown above the wordmark
    private var taglineKey: LocalizedStringKey {
        switch config.category {
        case .mind, .physical:  return "Practice facilitated by"
        case .productivity:     return "Focus brought to you by"
        }
    }

    // Wordmark + tagline stacked — alignment differs per layout
    private func cadenceLabel(alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: max(1, height * 0.002)) {
            Text(taglineKey)
                .font(.system(size: metaSize * 0.62, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.38))
                .tracking(metaSize * 0.10)
                .multilineTextAlignment(alignment == .center ? .center : .leading)
            Text("Cadence")
                .font(.system(size: metaSize * 1.55, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var totalDuration: String {
        let total = config.totalDurationSeconds          // includes all rounds
        if total >= 3600 {
            let h = total / 3600; let m = (total % 3600) / 60
            return m > 0 ? "\(h)h \(m)min" : "\(h)h"
        }
        let m = total / 60; let s = total % 60
        return s > 0 ? "\(m)m \(s)s" : "\(m) min"
    }

    private var formattedDate: String {
        // startDate here is actually the end time — passed correctly from SessionDoneOverlay
        let f = DateFormatter(); f.dateFormat = "EEE, HH:mm"
        return f.string(from: startDate)
    }

    // MARK: Body

    var body: some View {
        ZStack(alignment: .bottom) {

            // ── Full-bleed background ──────────────────────────────────────────
            backgroundFill
                .frame(width: width, height: height)
                .clipped()

            // ── Background dim ────────────────────────────────────────────────
            Color.black.opacity(backgroundDim)
                .frame(width: width, height: height)

            // ── Localised top gradient (text-area only) ───────────────────────
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.black.opacity(0.70), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(width: width, height: height * 0.32)
                Spacer()
            }
            .frame(width: width, height: height)

            // ── Localised bottom gradient (text-area only) ────────────────────
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.78)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: width, height: height * 0.40)

            // ── Layout-specific content ───────────────────────────────────────
            switch layout {
            case .classic:  classicContent
            case .centered: centeredContent
            case .header:   headerContent
            }

            // ── Photographer credit ───────────────────────────────────────────
            if let name = photographerName {
                Text("Background image by \(name) on Unsplash")
                    .font(.system(size: creditSize, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.30))
                    .padding(.horizontal, hPad)
                    .padding(.bottom, botPad * 0.45)
            }
        }
        .frame(width: width, height: height)
        .background(Color(hex: "0A0A0C"))
        .clipShape(RoundedRectangle(cornerRadius: radius))
    }

    // MARK: - Layout A · Classic
    // Header bar (Cadence | date) · rings centered · info bottom-left.

    private var classicContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                cadenceLabel(alignment: .leading)
                Spacer()
                Text(formattedDate)
                    .font(.system(size: metaSize, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.60))
            }
            .padding(.horizontal, hPad)
            .padding(.top, topPad)

            Spacer()

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                ShareRingsView(blocks: config.blocks, size: ringSize, strokeWidth: strokeW)
                    .frame(width: ringSize, height: ringSize)
                Spacer(minLength: 0)
            }

            Spacer()

            VStack(alignment: .leading, spacing: height * 0.013) {
                colorStrip()
                completedRow(alignment: .leading)
                locationRow(alignment: .leading)
                VStack(alignment: .leading, spacing: height * 0.005) {
                    Text(title)
                        .font(.system(size: nameSize, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2).minimumScaleFactor(0.8)
                    Text(config.category.displayName.uppercased())
                        .font(.system(size: catSize, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.50))
                        .tracking(catSize * 0.18)
                }
            }
            .padding(.horizontal, hPad)
            .padding(.bottom, photographerName != nil ? botPad * 2.2 : botPad)
        }
        .frame(width: width, height: height)
    }

    // MARK: - Layout B · Centered
    // Symmetric column; color strip is a full-width footer band.

    private var centeredContent: some View {
        ZStack(alignment: .topTrailing) {
            Text(formattedDate)
                .font(.system(size: metaSize, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.55))
                .padding(.horizontal, hPad)
                .padding(.top, topPad)

            VStack(spacing: 0) {
                Spacer()
                cadenceLabel(alignment: .center)
                Spacer().frame(height: height * 0.045)
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    ShareRingsView(blocks: config.blocks, size: ringSize, strokeWidth: strokeW)
                        .frame(width: ringSize, height: ringSize)
                    Spacer(minLength: 0)
                }
                Spacer().frame(height: height * 0.042)
                completedRow(alignment: .center)
                Spacer().frame(height: height * 0.010)
                locationRow(alignment: .center)
                Spacer().frame(height: height * 0.012)
                Text(title)
                    .font(.system(size: nameSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2).minimumScaleFactor(0.8)
                    .padding(.horizontal, hPad)
                Spacer().frame(height: height * 0.007)
                Text(config.category.displayName.uppercased())
                    .font(.system(size: catSize, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.50))
                    .tracking(catSize * 0.18)
                Spacer()
                colorStrip()
                    .padding(.bottom, photographerName != nil ? botPad * 2.0 : botPad * 0.8)
            }
            .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
    }

    // MARK: - Layout C · Header
    // Large title top-left · thick strip divider · rings · bottom bar.

    private var headerContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: height * 0.010) {
                Text(formattedDate)
                    .font(.system(size: metaSize, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.50))
                Text(title)
                    .font(.system(size: nameSize * 1.22, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(3).minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: catSize * 0.55) {
                    Text(config.category.displayName.uppercased())
                        .tracking(catSize * 0.18)
                    Text("·")
                    Text(totalDuration)
                }
                .font(.system(size: catSize, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.50))
            }
            .padding(.horizontal, hPad)
            .padding(.top, topPad)

            colorStrip(lineHeight: stripH * 3.5)
                .padding(.top, height * 0.020)

            Spacer()

            let smallRing = ringSize * 0.80
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                ShareRingsView(blocks: config.blocks, size: smallRing, strokeWidth: strokeW * 0.80)
                    .frame(width: smallRing, height: smallRing)
                Spacer(minLength: 0)
            }

            Spacer()

            VStack(alignment: .leading, spacing: height * 0.012) {
                HStack(alignment: .bottom) {
                    cadenceLabel(alignment: .leading)
                    Spacer()
                    HStack(spacing: catSize * 0.45) {
                        Image(systemName: "checkmark")
                            .font(.system(size: catSize * 0.85, weight: .bold))
                        Text("Completed")
                            .font(.system(size: catSize, weight: .semibold))
                    }
                    .foregroundStyle(Color.white.opacity(0.90))
                    .padding(.horizontal, catSize * 0.7)
                    .padding(.vertical, catSize * 0.38)
                    .background(Color.white.opacity(0.14))
                    .clipShape(Capsule())
                }
                locationRow(alignment: .leading)
            }
            .padding(.horizontal, hPad)
            .padding(.bottom, photographerName != nil ? botPad * 2.2 : botPad)
        }
        .frame(width: width, height: height)
    }

    // MARK: - Shared sub-views

    /// Compact "in Berlin" / "at Fitness First" label shown below the Completed pill.
    @ViewBuilder
    private func locationRow(alignment: HorizontalAlignment) -> some View {
        if let label = locationLabel {
            let content = HStack(spacing: catSize * 0.35) {
                Image(systemName: locationPrefix == "at" ? "mappin" : "location.fill")
                    .font(.system(size: catSize * 0.70))
                Text("\(locationPrefix) \(label)")
                    .font(.system(size: catSize * 0.88, weight: .medium))
            }
            .foregroundStyle(Color.white.opacity(0.65))

            if alignment == .center {
                content
            } else {
                HStack { content; Spacer(minLength: 0) }
            }
        }
    }

    @ViewBuilder
    private func completedRow(alignment: HorizontalAlignment) -> some View {
        let pill = HStack(spacing: catSize * 0.45) {
            Image(systemName: "checkmark")
                .font(.system(size: catSize * 0.85, weight: .bold))
            Text("Completed")
                .font(.system(size: catSize, weight: .semibold))
        }
        .foregroundStyle(Color.white.opacity(0.90))
        .padding(.horizontal, catSize * 0.7)
        .padding(.vertical, catSize * 0.38)
        .background(Color.white.opacity(0.14))
        .clipShape(Capsule())

        let dur = Text(totalDuration)
            .font(.system(size: catSize, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.55))

        if alignment == .center {
            HStack(spacing: catSize * 0.6) { pill; dur }
        } else {
            HStack(spacing: catSize * 0.6) { pill; dur; Spacer(minLength: 0) }
        }
    }

    private func colorStrip(lineHeight: CGFloat? = nil) -> some View {
        let h = lineHeight ?? stripH
        return GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(config.blocks) { block in
                    let total = Double(max(1, config.blocks.reduce(0) { $0 + $1.durationSeconds }))
                    let frac  = Double(block.durationSeconds) / total
                    block.color.color
                        .frame(width: max(4, geo.size.width * frac), height: geo.size.height)
                }
            }
        }
        .frame(height: h)
        .clipShape(Capsule())
    }

    // MARK: Background fill

    @ViewBuilder
    private var backgroundFill: some View {
        if let img = backgroundImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
        } else {
            // Fallback while no photo is loaded
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "0A0F18")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Static completion rings

private struct ShareRingsView: View {
    let blocks: [BlockConfig]
    let size: CGFloat
    let strokeWidth: CGFloat

    private var gap: CGFloat { strokeWidth * 0.65 }

    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                let r = (size / 2) - CGFloat(i) * (strokeWidth + gap) - strokeWidth / 2
                Circle()
                    .stroke(Color.white.opacity(0.07), lineWidth: strokeWidth)
                    .frame(width: r * 2, height: r * 2)
                Circle()
                    .trim(from: 0, to: 1.0)
                    .stroke(arcColor(ring: i),
                            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                    .frame(width: r * 2, height: r * 2)
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: size, height: size)
    }

    private func arcColor(ring: Int) -> Color {
        switch ring {
        case 0: return Color.white.opacity(0.25)
        case 1: return blocks.count > 1
            ? blocks[1].color.color.opacity(0.75)
            : blocks.first?.color.color.opacity(0.55) ?? Color.white.opacity(0.55)
        case 2: return blocks.first?.color.color ?? Color.white.opacity(0.85)
        default: return Color.white.opacity(0.30)
        }
    }
}

// MARK: - Photo picker (PHPickerViewController)

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var cfg = PHPickerConfiguration(photoLibrary: .shared())
        cfg.filter = .images; cfg.selectionLimit = 1
        let picker = PHPickerViewController(configuration: cfg)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    // @unchecked Sendable: Coordinator is only mutated on the main actor after init.
    class Coordinator: NSObject, PHPickerViewControllerDelegate, @unchecked Sendable {
        let parent: PhotoPicker
        init(_ parent: PhotoPicker) { self.parent = parent }

        nonisolated func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            Task { @MainActor in picker.dismiss(animated: true) }
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let self,
                      let image = object as? UIImage,
                      let data  = image.jpegData(compressionQuality: 0.95) else { return }
                Task { @MainActor [weak self] in
                    self?.parent.image = UIImage(data: data)
                }
            }
        }
    }
}

// MARK: - Camera picker (UIImagePickerController)

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate, @unchecked Sendable {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.image = img
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Share sheet modal

struct ShareSheetView: View {
    let config: TimerConfig
    let startDate: Date
    let endDate: Date          // actual wall-clock finish time — displayed on the card

    @Environment(\.dismiss) private var dismiss

    // Card customisation
    @State private var customTitle: String = ""
    @State private var selectedLayout: Int = 0

    // Background
    @State private var backgroundImage: UIImage? = nil
    @State private var backgroundDim: Double = 0.20
    @State private var photographerName: String? = nil
    @State private var selectedUnsplashID: Int? = nil  // set by onAppear to match category
    @State private var isLoadingPhoto: Bool = false

    // Custom photo
    @State private var showSourceDialog  = false
    @State private var showPhotoPicker   = false
    @State private var showCameraPicker  = false
    @State private var pickedPhoto: UIImage? = nil

    // Share feedback
    @State private var showSavedBanner = false
    @State private var savedBannerMessage: LocalizedStringKey = "Saved to Photos"

    // Location — auto-detected from GPS; user can override via map picker
    @State private var locationManager = LocationManager.shared
    @State private var manualLocationLabel: String? = nil
    @State private var manualLocationPrefix: String = "in"
    @State private var showLocationPicker = false

    private var displayTitle: String { customTitle.isEmpty ? config.name : customTitle }
    private var currentLayout: CardLayout { CardLayout(rawValue: selectedLayout) ?? .classic }

    // Export dimensions: 1080 × 1920 (9:16 Instagram Story)
    private let exportWidth:  CGFloat = 1080
    private let exportHeight: CGFloat = 1920

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerRow
                    cardPreview
                    photoPicker
                    titleEditor
                    locationEditor
                    dimControl
                    shareActions
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 60)
            }

            if showSavedBanner {
                Text(savedBannerMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                    .background(Color.surface3)
                    .clipShape(Capsule())
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker(image: $pickedPhoto)
        }
        .sheet(isPresented: $showCameraPicker) {
            CameraPicker(image: $pickedPhoto)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerSheet { prefix, label in
                manualLocationPrefix = prefix
                manualLocationLabel  = label
            }
        }
        .confirmationDialog("Use your own photo", isPresented: $showSourceDialog, titleVisibility: .visible) {
            Button("Photo Library") { showPhotoPicker = true }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo")  { showCameraPicker = true }
            }
            Button("Cancel", role: .cancel) { }
        }
        .onChange(of: pickedPhoto) { _, photo in
            guard let photo else { return }
            backgroundImage = photo
            photographerName = nil
            selectedUnsplashID = nil
        }
        .onAppear {
            customTitle = config.name
            locationManager.requestOnce()
            // Pick a random photo that matches the session's category;
            // fall back to any photo if none match.
            let candidates = unsplashPhotoLibrary.filter { $0.category == config.category }
            let pick = (candidates.isEmpty ? unsplashPhotoLibrary : candidates).randomElement()
            loadUnsplashPhoto(id: pick?.id ?? 0)
        }
        .presentationBackground(Color.bg)
        .presentationDetents([.large])
    }

    // MARK: Header

    private var headerRow: some View {
        HStack {
            // Close button — left
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(Color.surface2)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Share")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            Spacer()

            // Share button — right
            Button { shareViaSystemSheet() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Share")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(Color.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    // MARK: Card preview — swipeable layouts

    private var cardPreview: some View {
        VStack(spacing: 14) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = w * (16.0 / 9.0)   // 9:16 story ratio
                ZStack {
                    TabView(selection: $selectedLayout) {
                        ForEach(0..<CardLayout.allCases.count, id: \.self) { idx in
                            makeCard(width: w, height: h, layout: CardLayout.allCases[idx])
                                .overlay(RoundedRectangle(cornerRadius: w * 0.048)
                                    .strokeBorder(Color.borderDefault, lineWidth: 0.5))
                                .tag(idx)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(width: w, height: h)

                    // Loading overlay
                    if isLoadingPhoto {
                        RoundedRectangle(cornerRadius: w * 0.048)
                            .fill(Color.black.opacity(0.35))
                            .frame(width: w, height: h)
                        ProgressView()
                            .tint(.white)
                    }
                }
                .frame(width: w, height: h)
            }
            .aspectRatio(9.0 / 16.0, contentMode: .fit)

            // Page dots
            HStack(spacing: 6) {
                ForEach(0..<CardLayout.allCases.count, id: \.self) { idx in
                    Capsule()
                        .fill(selectedLayout == idx
                              ? Color.textPrimary
                              : Color.textTertiary.opacity(0.45))
                        .frame(width: selectedLayout == idx ? 18 : 6, height: 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedLayout)
                }
            }
        }
    }

    @ViewBuilder
    private func makeCard(width: CGFloat, height: CGFloat, layout: CardLayout) -> some View {
        ShareCard(
            config: config,
            title: displayTitle,
            startDate: endDate,      // pass actual finish time; ShareCard displays it as the date
            backgroundImage: backgroundImage,
            backgroundDim: backgroundDim,
            photographerName: photographerName,
            width: width,
            height: height,
            layout: layout,
            locationPrefix: manualLocationLabel != nil ? manualLocationPrefix : locationManager.prefix,
            locationLabel: manualLocationLabel ?? locationManager.placeLabel
        )
    }

    // MARK: Title editor

    private var titleEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Session Title")
            HStack(spacing: 10) {
                TextField(config.name, text: $customTitle)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textPrimary)
                    .tint(Color.accent)
                    .submitLabel(.done)
                if !customTitle.isEmpty && customTitle != config.name {
                    Button { customTitle = config.name } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.borderDefault, lineWidth: 0.5))
        }
    }

    // MARK: Photo picker

    private var photoPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Background Photo")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // Own photo button first
                    ownPhotoThumb

                    // Unsplash thumbnails
                    ForEach(unsplashPhotoLibrary) { photo in
                        unsplashThumb(photo)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private func unsplashThumb(_ photo: UnsplashPhoto) -> some View {
        let isSelected = selectedUnsplashID == photo.id
        Button { loadUnsplashPhoto(id: photo.id) } label: {
            AsyncImage(url: URL(string: photo.thumbnailURL)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                case .failure:
                    Color.surface3
                default:
                    Color.surface2.overlay(
                        ProgressView().scaleEffect(0.7).tint(Color.textTertiary)
                    )
                }
            }
            .frame(width: 56, height: 82)   // 9:16 mini card
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accent : Color.borderDefault,
                                  lineWidth: isSelected ? 2 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var ownPhotoThumb: some View {
        let isSelected = selectedUnsplashID == nil && pickedPhoto != nil
        return Button { showSourceDialog = true } label: {
            ZStack {
                if let img = pickedPhoto, isSelected {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 56, height: 82)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.surface2)
                        .frame(width: 56, height: 82)
                    VStack(spacing: 4) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.textSecondary)
                        Text("Own")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accent : Color.borderDefault,
                                  lineWidth: isSelected ? 2 : 0.5)
            )
            .frame(width: 56, height: 82)
        }
        .buttonStyle(.plain)
    }

    // MARK: Location editor

    private var locationEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Location")

            // Tap row → open map picker
            Button { showLocationPicker = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: effectiveLocationLabel != nil ? "mappin.circle.fill" : "mappin.slash")
                        .font(.system(size: 18))
                        .foregroundStyle(effectiveLocationLabel != nil ? Color.accent : Color.textTertiary)
                        .frame(width: 24)

                    if let label = effectiveLocationLabel {
                        Text("\(effectiveLocationPrefix) \(label)")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textPrimary)
                    } else {
                        Text("Tap to add location")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textTertiary)
                    }

                    Spacer()

                    Image(systemName: "map")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textTertiary)
                }
                .padding(14)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.borderDefault, lineWidth: 0.5))
            }
            .buttonStyle(.plain)

            // Clear manual override
            if manualLocationLabel != nil {
                Button {
                    manualLocationLabel = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 11))
                        Text("Clear manual location")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var effectiveLocationLabel: String? {
        manualLocationLabel ?? locationManager.placeLabel
    }
    private var effectiveLocationPrefix: String {
        manualLocationLabel != nil ? manualLocationPrefix : locationManager.prefix
    }

    // MARK: Dim control

    private var dimControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Dim Photo")
            HStack(spacing: 12) {
                Text("None")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
                Slider(value: $backgroundDim, in: 0.0...0.85)
                    .tint(Color.accent)
                Text("Dark")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(14)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.borderDefault, lineWidth: 0.5))
        }
    }

    // MARK: Share actions

    private var shareActions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                shareBtn(label: "Instagram", icon: "camera.fill",
                         bg: Color(hex: "833AB4")) { shareToInstagram() }
                shareBtn(label: "WhatsApp",  icon: "message.fill",
                         bg: Color(hex: "25D366")) { shareViaSystemSheet() }
            }
            HStack(spacing: 10) {
                shareBtn(label: "More",       icon: "square.and.arrow.up",
                         bg: Color.surface2)  { shareViaSystemSheet() }
                shareBtn(label: "Save Image", icon: "square.and.arrow.down",
                         bg: Color.surface2)  { saveToPhotoLibrary() }
            }
        }
    }

    private func shareBtn(
        label: LocalizedStringKey, icon: String, bg: Color,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 13))
                Text(label).font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.textTertiary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    // MARK: Unsplash photo loading

    private func loadUnsplashPhoto(id: Int) {
        guard let photo = unsplashPhotoLibrary.first(where: { $0.id == id }) else { return }
        selectedUnsplashID = id
        photographerName = photo.photographer
        isLoadingPhoto = true
        Task {
            defer { Task { @MainActor in isLoadingPhoto = false } }
            guard let url = URL(string: photo.url),
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let img = UIImage(data: data) else { return }
            await MainActor.run {
                backgroundImage = img
            }
        }
    }

    // MARK: Render — 1080 × 1920 JPEG, current layout

    @MainActor
    private func renderCardData() -> Data? {
        let card = makeCard(
            width: exportWidth,
            height: exportHeight,
            layout: currentLayout
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 1.0   // already at export resolution
        renderer.proposedSize = ProposedViewSize(width: exportWidth, height: exportHeight)
        return renderer.uiImage?.jpegData(compressionQuality: 0.95)
    }

    // MARK: Actions

    @MainActor private func shareToInstagram() {
        guard let data = renderCardData() else { return }
        UIPasteboard.general.setData(data,
            forPasteboardType: "com.instagram.sharedSticker.backgroundImage")
        let scheme = "instagram-stories://share?source_application=com.cadence.app"
        if let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            shareViaSystemSheet()
        }
    }

    @MainActor private func shareViaSystemSheet() {
        guard let data = renderCardData() else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cadence-session.jpg")
        try? data.write(to: url)
        present(UIActivityViewController(activityItems: [url], applicationActivities: nil))
    }

    @MainActor private func saveToPhotoLibrary() {
        guard let data = renderCardData() else { return }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".jpg")
        guard (try? data.write(to: tempURL)) != nil else { return }

        Task {
            defer { try? FileManager.default.removeItem(at: tempURL) }
            do {
                // saveImageToPhotoLibrary is a nonisolated free function —
                // the change block runs on Photos' own queue, not the main actor.
                try await saveImageToPhotoLibrary(at: tempURL)
                savedBannerMessage = "Saved to Photos"
                withAnimation(.easeOut(duration: 0.25)) { showSavedBanner = true }
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                withAnimation(.easeIn(duration: 0.25)) { showSavedBanner = false }
            } catch {
                // save failed silently
            }
        }
    }

    @MainActor private func present(_ vc: UIViewController) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first,
              let root   = window.rootViewController else { return }
        var top = root
        while let next = top.presentedViewController { top = next }
        top.present(vc, animated: true)
    }
}
