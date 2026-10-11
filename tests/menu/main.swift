import Foundation

func profile(_ fh: Int?, _ weekly: Int?, extra: [[String: Any]] = [],
             label: String = "Account 1", age: Int? = 720,
             loggedIn: Bool = true, number: Int = 1) -> Profile {
    var windows: [[String: Any]] = []
    if let fh { windows.append(["key": "five_hour", "percentUsed": fh]) }
    if let weekly { windows.append(["key": "weekly", "percentUsed": weekly]) }
    var json: [String: Any] = [
        "n": number, "label": label, "active": true, "logged_in": loggedIn, "sessions": 0,
        "windows": windows + extra
    ]
    if let age { json["age"] = age }
    let data = try! JSONSerialization.data(withJSONObject: json)
    return try! JSONDecoder().decode(Profile.self, from: data)
}

let weekly = profile(14, 96)
assert(weekly.menuBarTitle == "Account 1 · 7 d 4%")
assert(weekly.usageWindows.map { $0.remaining } == ["86% left", "4% left"])
assert(weekly.updated == "Updated 12 min ago")
assert(profile(99, 96).menuBarTitle == "Account 1 · 5 h 1%")
assert(profile(97, 97).limitingWindow?.key == "weekly")
assert(profile(14, 96, extra: [["key": "weekly_fable", "percentUsed": 100]]).limitingWindow?.key == "weekly")
assert(profile(nil, 96).menuBarTitle.contains("7 d 4%"))
assert(profile(nil, nil).menuBarTitle == "Account 1 · ?")
assert(profile(100, 0).limitingWindow?.remainingPercent == 0)
assert(profile(140, 0).limitingWindow?.remainingPercent == 0)
assert(profile(-10, nil).limitingWindow?.remainingPercent == 100)
let future = (Date().timeIntervalSince1970 + 86400) * 1000
assert(Window(key: "weekly", label: nil, percentUsed: 96, resetsAt: future, estimated: true).reset == nil)
assert(Window(key: "weekly", label: nil, percentUsed: 96, resetsAt: future, estimated: false).reset != nil)
assert(Window(key: "weekly", label: nil, percentUsed: 96, resetsAt: 1, estimated: false).reset == nil)
assert(Window(key: "weekly", label: nil, percentUsed: 96, resetsAt: nil, estimated: nil).reset == nil)

// Compact labels preserve the full name and truncate at a character boundary.
let longName = profile(20, nil, label: "Development workspace account")
assert(longName.displayName == "Development workspace account")
assert(longName.compactName.count == 20 && longName.compactName.hasSuffix("…"))
assert(longName.menuBarTitle == "Development workspa… · 5 h 80%")
assert(profile(nil, nil, label: "  Team account \n").displayName == "Team account")
assert(profile(nil, nil, label: "  \n", number: 3).displayName == "Profile 3")
let emojiName = String(repeating: "👩🏽‍💻", count: 21)
assert(profile(nil, nil, label: emojiName).compactName == String(repeating: "👩🏽‍💻", count: 19) + "…")
assert(profile(20, 90, loggedIn: false).menuBarTitle == "Account 1 · Sign in")

// Missing usage has no numeric value, and model limits remain explicitly scoped.
let unavailable = profile(nil, nil, age: nil)
assert(unavailable.usageWindows.allSatisfy { $0.remainingPercent == nil })
assert(unavailable.cacheSummary == "No usage saved")
assert(profile(10, nil, age: nil).cacheSummary == "Cache time unknown")
assert(profile(10, nil, age: 59).cacheSummary == "Saved just now")
assert(profile(10, nil, age: 60).cacheSummary == "Saved 1 min ago")
assert(profile(10, nil, age: 3600).cacheSummary == "Saved 1 h ago")
assert(weekly.cacheSummary == "Saved 12 min ago")
assert(unavailable.usageWindows.map { $0.displayTitle } == ["5-hour", "Weekly"])
let modelOnly = profile(nil, nil, extra: [
    ["key": "weekly_fable", "label": "Weekly · Fable", "percentUsed": 100]
])
assert(modelOnly.usageWindows.first?.displayTitle == "Fable · weekly")
assert(modelOnly.limitingWindow == nil && modelOnly.menuBarTitle == "Account 1 · ?")
assert(unavailable.accessibilityUsage.contains("5-hour: usage unavailable"))
assert(!unavailable.accessibilityUsage.contains("0 percent"))
assert(modelOnly.accessibilityUsage.contains("Fable · weekly: 0 percent remaining"))
assert(profile(20, 90, loggedIn: false).accessibilityUsage == "Sign-in required")
print("Menu usage tests passed")
