import Foundation
import CoreGraphics

/// UI geometry only. Countdown/expiration are owned by ClientRestTimerState.
enum ClientFloatingTimerPlacement {
    static func center(preferred: CGPoint, bounds: CGRect, diameter: CGFloat, avoiding: [CGRect]) -> CGPoint? {
        guard preferred.x.isFinite, preferred.y.isFinite, diameter.isFinite, diameter > 0,
              bounds.width.isFinite, bounds.height.isFinite, !bounds.isNull,
              bounds.width >= diameter + 16, bounds.height >= diameter + 16 else { return nil }
        let radius = diameter / 2
        let area = bounds.insetBy(dx: radius + 8, dy: radius + 8)
        guard !area.isNull, area.minX.isFinite, area.maxX.isFinite, area.minY.isFinite, area.maxY.isFinite else { return nil }
        let xValues = preferred.x < bounds.midX ? [area.minX, area.maxX] : [area.maxX, area.minX]
        let blocked = avoiding.map { $0.insetBy(dx: -radius - 8, dy: -radius - 8) }
        for x in xValues {
            let y = min(area.maxY, max(area.minY, preferred.y))
            var candidates = [y, area.minY, area.maxY]
            for rect in blocked where x >= rect.minX && x <= rect.maxX {
                candidates += [rect.minY - 1, rect.maxY + 1]
            }
            if let clear = candidates.filter({ $0 >= area.minY && $0 <= area.maxY })
                .sorted(by: { abs($0 - y) < abs($1 - y) })
                .first(where: { candidate in !blocked.contains { $0.contains(CGPoint(x: x, y: candidate)) } }) {
                return CGPoint(x: x, y: clear)
            }
        }
        return nil // Caller uses reserved native accessory lane, never covers inputs.
    }
}
