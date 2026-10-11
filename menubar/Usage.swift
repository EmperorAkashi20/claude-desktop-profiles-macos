import Foundation

struct Window: Decodable {
    let key: String
    let label: String?
    let percentUsed: Int?
    let resetsAt: Double?
    let estimated: Bool?

    var short: String {
        switch key {
        case "five_hour": return "5 h"
        case "weekly": return "7 d"
        default:
            if let l = label, l.contains("·") {
                return l.components(separatedBy: "·").last!.trimmingCharacters(in: .whitespaces)
            }
            return label ?? key
        }
    }

    var remainingPercent: Int? { percentUsed.map { max(0, min(100, 100 - $0)) } }
    var remaining: String { remainingPercent.map { "\($0)% left" } ?? "unknown" }

    var displayTitle: String {
        switch key {
        case "five_hour": return "5-hour"
        case "weekly": return "Weekly"
        default: return key.hasPrefix("weekly_") ? "\(short) · weekly" : short
        }
    }

    var reset: String? {
        // Also suppress estimates from an older CLI and expired recorded times.
        guard estimated != true, let ms = resetsAt, ms.isFinite,
              ms > Date().timeIntervalSince1970 * 1000 else { return nil }
        let date = Date(timeIntervalSince1970: ms / 1000)
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "EEE HH:mm"
        return formatter.string(from: date)
    }
}

struct Profile: Decodable {
    let n: Int
    let label: String
    let active: Bool
    let logged_in: Bool
    let sessions: Int
    let fh: Int?
    let sd: Int?
    let windows: [Window]?
    let age: Int?

    var usageWindows: [Window] {
        if let windows, !windows.isEmpty { return windows }
        return [Window(key: "five_hour", label: nil, percentUsed: fh, resetsAt: nil, estimated: nil),
                Window(key: "weekly", label: nil, percentUsed: sd, resetsAt: nil, estimated: nil)]
    }

    var limitingWindow: Window? {
        // A model-specific cap must not be presented as exhaustion of the whole account.
        usageWindows.filter { ($0.key == "five_hour" || $0.key == "weekly") && $0.remainingPercent != nil }
            .sorted {
                if $0.remainingPercent != $1.remainingPercent {
                    return $0.remainingPercent! < $1.remainingPercent!
                }
                return $0.key == "weekly" && $1.key != "weekly"
            }.first
    }

    var displayName: String {
        let name = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Profile \(n)" : name
    }

    var compactName: String {
        displayName.count > 20 ? String(displayName.prefix(19)) + "…" : displayName
    }

    var menuBarTitle: String {
        guard logged_in else { return compactName + " · Sign in" }
        guard let window = limitingWindow, let remaining = window.remainingPercent else {
            return compactName + " · ?"
        }
        return compactName + " · " + window.short + " \(remaining)%"
    }

    var cacheSummary: String {
        guard let age else {
            return usageWindows.contains(where: { $0.remainingPercent != nil })
                ? "Cache time unknown" : "No usage saved"
        }
        if age < 60 { return "Saved just now" }
        if age < 3600 { return "Saved \(age / 60) min ago" }
        return "Saved \(age / 3600) h ago"
    }

    var accessibilityUsage: String {
        guard logged_in else { return "Sign-in required" }
        let limits = usageWindows.map { window in
            let remaining = window.remainingPercent.map { "\($0) percent remaining" } ?? "usage unavailable"
            let reset = window.reset.map { ", resets \($0)" } ?? ""
            return "\(window.displayTitle): \(remaining)\(reset)"
        }
        return ([cacheSummary, "Cached usage"] + limits).joined(separator: ". ")
    }

    var updated: String {
        guard let age else { return "Usage unavailable" }
        if age < 60 { return "Updated just now" }
        if age < 3600 { return "Updated \(age / 60) min ago" }
        return "Updated \(age / 3600) h ago"
    }
}

struct Status: Decodable { let active: Int?; let profiles: [Profile] }
