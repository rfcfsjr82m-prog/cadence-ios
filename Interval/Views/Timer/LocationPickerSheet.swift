import SwiftUI
import MapKit
import CoreLocation

// MARK: - LocationPickerSheet
//
// Full-bleed map with a floating search-results panel at the bottom.
// Tapping a suggestion zooms the map and shows a Confirm button.

struct LocationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onConfirm: (_ prefix: String, _ label: String) -> Void

    @State private var searchText  = ""
    @State private var completer   = PlaceSearchCompleter()
    @State private var isResolving = false

    // Pending result — shown on map before user confirms
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var pendingCoord:   CLLocationCoordinate2D? = nil
    @State private var pendingPrefix:  String = "in"
    @State private var pendingLabel:   String = ""
    @State private var hasPending:     Bool   = false

    private var showResults: Bool {
        !completer.completions.isEmpty || (!searchText.isEmpty && !isResolving)
    }

    var body: some View {
        NavigationStack {
            // Map fills the entire sheet
            Map(position: $cameraPosition) {
                if let coord = pendingCoord {
                    Marker(pendingLabel, coordinate: coord)
                        .tint(.accent)
                } else if let coord = LocationManager.shared.lastKnownCoordinate {
                    Marker("You are here", coordinate: coord)
                        .tint(.blue)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .overlay(alignment: .bottom) {
                VStack(spacing: 0) {

                    // ── Search results panel ─────────────────────────────────
                    if showResults {
                        VStack(spacing: 0) {
                            if completer.completions.isEmpty {
                                Text("No results")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 16)
                                    .frame(maxWidth: .infinity)
                            } else {
                                ScrollView {
                                    VStack(spacing: 0) {
                                        ForEach(completer.completions, id: \.self) { completion in
                                            Button {
                                                resolve(completion)
                                            } label: {
                                                VStack(alignment: .leading, spacing: 3) {
                                                    Text(completion.title)
                                                        .font(.system(size: 15))
                                                        .foregroundStyle(.primary)
                                                    if !completion.subtitle.isEmpty {
                                                        Text(completion.subtitle)
                                                            .font(.system(size: 13))
                                                            .foregroundStyle(.secondary)
                                                    }
                                                }
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 12)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)
                                            .disabled(isResolving)

                                            if completion != completer.completions.last {
                                                Divider().padding(.leading, 16)
                                            }
                                        }
                                    }
                                }
                                .frame(maxHeight: 260)
                            }
                        }
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: -4)
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // ── Confirm button ───────────────────────────────────────
                    if hasPending {
                        Button {
                            onConfirm(pendingPrefix, pendingLabel)
                            dismiss()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: pendingPrefix == "at" ? "mappin" : "location.fill")
                                    .font(.system(size: 13))
                                Text("Use \"\(pendingPrefix) \(pendingLabel)\"")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 13)
                            .background(Color.accent)
                            .clipShape(Capsule())
                            .shadow(radius: 6)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.bottom, 32)
                .animation(.spring(response: 0.35, dampingFraction: 0.85),
                           value: showResults)
                .animation(.spring(response: 0.35, dampingFraction: 0.85),
                           value: hasPending)
            }
            .overlay {
                if isResolving {
                    ProgressView("Looking up…")
                        .padding(24)
                        .background(.regularMaterial,
                                    in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .searchable(text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Gym, city, neighbourhood…")
            .onChange(of: searchText) { _, query in
                completer.update(query: query)
                if !query.isEmpty { hasPending = false }
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { centerOnCurrentLocation() }
        }
    }

    // MARK: - Helpers

    private func centerOnCurrentLocation() {
        guard let coord = LocationManager.shared.lastKnownCoordinate else { return }
        cameraPosition = .region(MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    }

    private func resolve(_ completion: MKLocalSearchCompletion) {
        isResolving = true
        let request = MKLocalSearch.Request(completion: completion)
        MKLocalSearch(request: request).start { response, _ in
            DispatchQueue.main.async {
                isResolving = false
                guard let item = response?.mapItems.first else { return }

                let placemark = item.placemark
                let name      = item.name ?? ""
                let locality  = placemark.locality
                let admin     = placemark.administrativeArea
                let country   = placemark.country
                let coord     = placemark.coordinate

                let prefix: String
                let label: String
                if !name.isEmpty, name != locality, name != admin {
                    prefix = "at"; label = name
                } else if let city = locality {
                    prefix = "in"; label = city
                } else if let region = admin, let ctry = country {
                    prefix = "in"; label = "\(region), \(ctry)"
                } else if let ctry = country {
                    prefix = "in"; label = ctry
                } else {
                    prefix = "at"; label = name
                }

                pendingCoord  = coord
                pendingPrefix = prefix
                pendingLabel  = label
                hasPending    = true

                withAnimation {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
                    ))
                }
            }
        }
    }
}

// MARK: - PlaceSearchCompleter

@Observable
final class PlaceSearchCompleter: NSObject, MKLocalSearchCompleterDelegate, @unchecked Sendable {

    var completions: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate    = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(query: String) {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            completions = []
            completer.queryFragment = ""
        } else {
            completer.queryFragment = query
        }
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        completions = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        completions = []
    }
}
