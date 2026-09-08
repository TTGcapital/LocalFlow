import Foundation

struct MeetingWindowMatcher {
    static func matches(bundle: String, title: String) -> Bool {
        let title = title.lowercased()
        if bundle == "us.zoom.xos" { return title == "zoom meeting" || title == "zoom webinar" || title.hasPrefix("zoom meeting:") }
        let browsers = ["com.google.Chrome", "com.apple.Safari", "org.mozilla.firefox", "com.microsoft.edgemac", "company.thebrowser.Browser"]
        return browsers.contains(bundle) && (title.hasPrefix("meet – ") || title.hasPrefix("meet - ") || title.hasPrefix("google meet - ") || title.hasPrefix("google meet – ")) && !title.contains("landing")
    }
}

