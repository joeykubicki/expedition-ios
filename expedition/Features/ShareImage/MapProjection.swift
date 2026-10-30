import CoreGraphics
import Foundation

/// Flattens coordinates for the share image. Output is in projection units
/// with y pointing up (north); `PosterMap` scales and flips it.
nonisolated enum MapProjection {
    /// Equal Earth (Šavrič, Patterson & Jenny, 2018): a world map that keeps
    /// areas true, so Greenland isn't the size of Africa. The world spans
    /// about ±2.71 by ±1.32.
    static func equalEarth(_ coordinate: Coordinate) -> CGPoint {
        let (a1, a2, a3, a4) = (1.340264, -0.081106, 0.000893, 0.003796)
        let longitude = coordinate.longitude * .pi / 180
        let theta = asin(sqrt(3) / 2 * sin(coordinate.latitude * .pi / 180))
        let t2 = theta * theta, t6 = t2 * t2 * t2
        let x = 2 * sqrt(3) * longitude * cos(theta) / (3 * (9 * a4 * t6 * t2 + 7 * a3 * t6 + 3 * a2 * t2 + a1))
        let y = theta * (a1 + a2 * t2 + t6 * (a3 + a4 * t2))
        return CGPoint(x: x, y: y)
    }

    /// Albers equal-area conic, the projection of printed US maps.
    struct Albers: Sendable {
        let centralMeridian: Double
        private let n: Double
        private let c: Double
        private let rho0: Double

        /// Standard parallels and origin in degrees.
        init(parallels: (Double, Double), origin: (latitude: Double, longitude: Double)) {
            let phi1 = parallels.0 * .pi / 180, phi2 = parallels.1 * .pi / 180
            n = (sin(phi1) + sin(phi2)) / 2
            c = cos(phi1) * cos(phi1) + 2 * n * sin(phi1)
            rho0 = sqrt(c - 2 * n * sin(origin.latitude * .pi / 180)) / n
            centralMeridian = origin.longitude
        }

        func project(_ coordinate: Coordinate) -> CGPoint {
            // Wrap so the Aleutians west of 180° stay next to the rest of Alaska.
            var delta = coordinate.longitude - centralMeridian
            if delta > 180 { delta -= 360 } else if delta < -180 { delta += 360 }
            let rho = sqrt(c - 2 * n * sin(coordinate.latitude * .pi / 180)) / n
            let theta = n * delta * .pi / 180
            return CGPoint(x: rho * sin(theta), y: rho0 - rho * cos(theta))
        }

        /// The USGS parameters for each part of the US map.
        static let lower48 = Albers(parallels: (29.5, 45.5), origin: (37.5, -96))
        static let alaska = Albers(parallels: (55, 65), origin: (50, -154))
        static let hawaii = Albers(parallels: (8, 18), origin: (3, -157))
    }
}
