import Foundation

enum Formatters {
    static func compactTokens(_ n: Int) -> String {
        let absN = abs(n)
        switch absN {
        case 1_000_000_000...:
            return String(format: "%.1fB", Double(n) / 1_000_000_000)
        case 1_000_000...:
            return String(format: "%.1fM", Double(n) / 1_000_000)
        case 10_000...:
            return String(format: "%.0fk", Double(n) / 1_000)
        case 1_000...:
            return String(format: "%.1fk", Double(n) / 1_000)
        default:
            return "\(n)"
        }
    }

    static func remaining(_ interval: TimeInterval) -> String {
        if interval <= 0 { return "now" }
        let total = Int(interval)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    static func clockTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    static func relative(_ date: Date, now: Date = Date()) -> String {
        let interval = now.timeIntervalSince(date)
        if interval < 60 { return "just now" }
        let mins = Int(interval / 60)
        if mins < 60 { return "\(mins) minute\(mins == 1 ? "" : "s") ago" }
        let hrs = mins / 60
        return "\(hrs) hour\(hrs == 1 ? "" : "s") ago"
    }
}
