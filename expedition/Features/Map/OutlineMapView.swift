import MapKit
import SwiftUI

/// The States and Countries maps: one overlay per place on an `MKMapView`,
/// added once and recolored in place when a place is marked or selected.
/// SwiftUI's `Map` re-diffs every overlay on each change, which froze the app
/// for over a second with the ~1,400 country polygons.
struct OutlineMapView: UIViewRepresentable {
    let outlines: [PlaceOutline]
    /// The category's places, for finding what was tapped.
    let places: [Place]
    let visitedCodes: Set<String>
    let bucketListCodes: Set<String>
    let selectedPlaceID: PlaceID?
    let visitedColor: Color
    @Binding var position: MapCameraPosition
    /// The place under a tap, or `nil` for water.
    let onTap: (Place?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = PositionedMapView()
        let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        configuration.pointOfInterestFilter = .excludingAll
        mapView.preferredConfiguration = configuration
        mapView.delegate = context.coordinator
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        tap.delegate = context.coordinator
        mapView.addGestureRecognizer(tap)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.update(mapView, from: self, environment: context.environment)
    }

    /// Theme colors resolved for the current appearance.
    private struct Palette: Equatable {
        let visited: Color.Resolved
        let bucketList: Color.Resolved
        let land: Color.Resolved
        let boundary: Color.Resolved
        let selection: Color.Resolved
        let bucketListBorder: Color.Resolved

        init(visitedColor: Color, in environment: EnvironmentValues) {
            visited = visitedColor.opacity(0.75).resolve(in: environment)
            bucketList = Color.visitedSoft.opacity(0.8).resolve(in: environment)
            land = Color.land.opacity(0.6).resolve(in: environment)
            boundary = Color.boundary.resolve(in: environment)
            selection = Color.ink.resolve(in: environment)
            bucketListBorder = visitedColor.resolve(in: environment)
        }
    }

    private enum Border {
        /// A place's border, for places cut at the antimeridian.
        case seam
        case bucketList
        case selection
    }

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        private var view: OutlineMapView?
        private var palette: Palette?
        private var visitedCodes: Set<String> = []
        private var bucketListCodes: Set<String> = []
        private var outlines: [String: PlaceOutline] = [:]
        /// Fill overlays by place code, and back.
        private var fills: [String: MKMultiPolygon] = [:]
        private var fillCodes: [ObjectIdentifier: String] = [:]
        private var borders: [ObjectIdentifier: Border] = [:]
        private var seams: [MKMultiPolyline] = []
        private var bucketListBorders: [String: MKMultiPolyline] = [:]
        private var selection: (code: String, overlay: MKMultiPolyline)?
        private var shownPosition: MapCameraPosition?

        func update(_ mapView: MKMapView, from view: OutlineMapView, environment: EnvironmentValues) {
            self.view = view
            if fills.isEmpty, !view.outlines.isEmpty {
                add(view.outlines, to: mapView)
            }

            let palette = Palette(visitedColor: view.visitedColor, in: environment)
            let paletteChanged = palette != self.palette
            let restyled: Set<String> = paletteChanged
                ? Set(fills.keys)
                : visitedCodes.symmetricDifference(view.visitedCodes)
                    .union(bucketListCodes.symmetricDifference(view.bucketListCodes))
            self.palette = palette
            visitedCodes = view.visitedCodes
            bucketListCodes = view.bucketListCodes
            for code in restyled {
                guard let fill = fills[code], let renderer = mapView.renderer(for: fill) as? MKMultiPolygonRenderer else { continue }
                style(renderer, code: code)
                renderer.setNeedsDisplay()
            }
            if paletteChanged {
                for overlay in mapView.overlays {
                    guard let renderer = mapView.renderer(for: overlay) as? MKMultiPolylineRenderer,
                          let border = borders[ObjectIdentifier(overlay)] else { continue }
                    style(renderer, as: border)
                    renderer.setNeedsDisplay()
                }
            }

            updateSelection(view.selectedPlaceID?.code, on: mapView)
            updateBucketListBorders(on: mapView)
            if view.position != shownPosition {
                shownPosition = view.position
                (mapView as? PositionedMapView)?.show(view.position)
            }
        }

        private func add(_ placeOutlines: [PlaceOutline], to mapView: MKMapView) {
            for outline in placeOutlines {
                let code = outline.placeID.code
                outlines[code] = outline
                fills[code] = outline.fill
                fillCodes[ObjectIdentifier(outline.fill)] = code
                if outline.hasSeam {
                    let seam = MKMultiPolyline(outline.outline)
                    borders[ObjectIdentifier(seam)] = .seam
                    seams.append(seam)
                }
            }
            mapView.addOverlays(placeOutlines.map(\.fill), level: .aboveRoads)
            mapView.addOverlays(seams, level: .aboveRoads)
        }

        /// The selected place's border goes on top of everything.
        private func updateSelection(_ code: String?, on mapView: MKMapView) {
            guard code != selection?.code else { return }
            if let selection {
                mapView.removeOverlay(selection.overlay)
                borders[ObjectIdentifier(selection.overlay)] = nil
            }
            selection = nil
            guard let code, let outline = outlines[code] else { return }
            let overlay = MKMultiPolyline(outline.outline)
            borders[ObjectIdentifier(overlay)] = .selection
            mapView.addOverlay(overlay, level: .aboveRoads)
            selection = (code, overlay)
        }

        /// Dashed borders on bucket-list places, over their neighbors' solid
        /// ones (the cue that isn't just color) and under the selection.
        private func updateBucketListBorders(on mapView: MKMapView) {
            let wanted = bucketListCodes.filter { outlines[$0] != nil }
            for (code, overlay) in bucketListBorders where !wanted.contains(code) {
                mapView.removeOverlay(overlay)
                borders[ObjectIdentifier(overlay)] = nil
                bucketListBorders[code] = nil
            }
            for code in wanted where bucketListBorders[code] == nil {
                guard let outline = outlines[code] else { continue }
                let overlay = MKMultiPolyline(outline.outline)
                borders[ObjectIdentifier(overlay)] = .bucketList
                bucketListBorders[code] = overlay
                if let selection {
                    mapView.insertOverlay(overlay, below: selection.overlay)
                } else {
                    mapView.addOverlay(overlay, level: .aboveRoads)
                }
            }
        }

        private func style(_ renderer: MKMultiPolygonRenderer, code: String) {
            guard let palette else { return }
            let fill = visitedCodes.contains(code) ? palette.visited
                : bucketListCodes.contains(code) ? palette.bucketList
                : palette.land
            renderer.fillColor = UIColor(cgColor: fill.cgColor)
            renderer.strokeColor = outlines[code]?.hasSeam == true ? .clear : UIColor(cgColor: palette.boundary.cgColor)
            renderer.lineWidth = 0.5
        }

        private func style(_ renderer: MKMultiPolylineRenderer, as border: Border) {
            guard let palette else { return }
            switch border {
            case .seam:
                renderer.strokeColor = UIColor(cgColor: palette.boundary.cgColor)
                renderer.lineWidth = 0.5
            case .bucketList:
                renderer.strokeColor = UIColor(cgColor: palette.bucketListBorder.cgColor)
                renderer.lineWidth = 1.5
                renderer.lineDashPattern = [5, 3]
            case .selection:
                renderer.strokeColor = UIColor(cgColor: palette.selection.cgColor)
                renderer.lineWidth = 2.5
            }
        }

        // MARK: MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            let id = ObjectIdentifier(overlay)
            if let fill = overlay as? MKMultiPolygon, let code = fillCodes[id] {
                let renderer = MKMultiPolygonRenderer(multiPolygon: fill)
                style(renderer, code: code)
                return renderer
            }
            if let lines = overlay as? MKMultiPolyline, let border = borders[id] {
                let renderer = MKMultiPolylineRenderer(multiPolyline: lines)
                style(renderer, as: border)
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        /// Remembers where the map is, so switching to the list and back
        /// returns to the same spot.
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            guard (mapView as? PositionedMapView)?.isPositioned == true else { return }
            let camera = mapView.camera
            let position = MapCameraPosition.camera(MapCamera(
                centerCoordinate: camera.centerCoordinate,
                distance: camera.centerCoordinateDistance,
                heading: camera.heading,
                pitch: camera.pitch
            ))
            shownPosition = position
            // Not during a view update, which this can be called from.
            let binding = view?.$position
            Task { @MainActor in
                binding?.wrappedValue = position
            }
        }

        // MARK: Taps

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView, let view else { return }
            let coordinate = mapView.convert(gesture.location(in: mapView), toCoordinateFrom: mapView)
            view.onTap(PlaceHitTester.place(
                at: Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude),
                in: view.places
            ))
        }

        /// Taps select a place without blocking the map's own gestures.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

/// Holds a camera position until the map has a size to apply it to.
private final class PositionedMapView: MKMapView {
    private var pending: MapCameraPosition?
    /// Whether a position has been applied; until then, region changes are
    /// MapKit's own default and aren't worth remembering.
    private(set) var isPositioned = false

    func show(_ position: MapCameraPosition) {
        if bounds.isEmpty {
            pending = position
        } else {
            apply(position)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let pending, !bounds.isEmpty {
            self.pending = nil
            apply(pending)
        }
    }

    private func apply(_ position: MapCameraPosition) {
        if let camera = position.camera {
            setCamera(MKMapCamera(
                lookingAtCenter: camera.centerCoordinate,
                fromDistance: camera.distance,
                pitch: camera.pitch,
                heading: camera.heading
            ), animated: false)
        } else if let region = position.region {
            setRegion(region, animated: false)
        } else if let rect = position.rect {
            setVisibleMapRect(rect, animated: false)
        }
        isPositioned = true
    }
}
