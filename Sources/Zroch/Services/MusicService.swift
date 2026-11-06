import AppKit
import Combine

/// Now-playing info and playback control for Apple Music and Spotify, via AppleScript.
final class MusicService: ObservableObject {
    static let shared = MusicService()

    enum Player: String {
        case music = "Music", spotify = "Spotify"
        var bundleID: String { self == .music ? "com.apple.Music" : "com.spotify.client" }
    }

    struct Track {
        var state: String
        var title: String
        var artist: String
        var album: String
        var position: Double
        var duration: Double
        var artworkURL: String
    }

    @Published var player: Player?
    @Published var isPlaying = false
    @Published var title = ""
    @Published var artist = ""
    @Published var album = ""
    @Published var position: Double = 0
    @Published var duration: Double = 0
    @Published var artwork: NSImage?

    private let queue = DispatchQueue(label: "zroch.music")
    private var scripts: [String: NSAppleScript] = [:]
    private var timer: Timer?
    private var trackKey = ""

    func start() {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.poll() }
    }

    private func isRunning(_ p: Player) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: p.bundleID).isEmpty
    }

    private func poll() {
        let candidates = [Player.spotify, .music].filter(isRunning)
        guard !candidates.isEmpty else { apply(nil, nil); return }
        queue.async { [weak self] in
            guard let self else { return }
            var best: (Player, Track)?
            for p in candidates {
                guard let t = self.fetch(p), t.state != "stopped" else { continue }
                if t.state == "playing" { best = (p, t); break }
                if best == nil { best = (p, t) }
            }
            DispatchQueue.main.async { self.apply(best?.0, best?.1) }
        }
    }

    private func apply(_ p: Player?, _ t: Track?) {
        guard let p, let t else {
            if player != nil { player = nil; isPlaying = false; title = ""; artist = ""; artwork = nil; trackKey = "" }
            return
        }
        player = p
        isPlaying = t.state == "playing"
        title = t.title; artist = t.artist; album = t.album
        position = t.position; duration = t.duration
        let key = "\(p.rawValue)|\(t.title)|\(t.artist)|\(t.album)"
        if key != trackKey {
            trackKey = key
            artwork = nil
            loadArtwork(p, t)
        }
    }

    // MARK: AppleScript

    private func run(_ source: String) -> NSAppleEventDescriptor? {
        let script: NSAppleScript
        if let cached = scripts[source] {
            script = cached
        } else {
            guard let s = NSAppleScript(source: source) else { return nil }
            var err: NSDictionary?
            s.compileAndReturnError(&err)
            if err != nil { return nil }
            scripts[source] = s
            script = s
        }
        var err: NSDictionary?
        let result = script.executeAndReturnError(&err)
        return err == nil ? result : nil
    }

    private func fetch(_ p: Player) -> Track? {
        let durationExpr = p == .spotify ? "(duration of t) / 1000" : "duration of t"
        let artExpr = p == .spotify ? "artwork url of t" : "\"\""
        let src = """
        tell application "\(p.rawValue)"
            try
                set s to player state as string
                if s is "stopped" then return {s, "", "", "", 0, 0, ""}
                set t to current track
                return {s, name of t, artist of t, album of t, player position, \(durationExpr), \(artExpr)}
            on error
                return {"stopped", "", "", "", 0, 0, ""}
            end try
        end tell
        """
        guard let d = run(src), d.numberOfItems >= 7 else { return nil }
        func str(_ i: Int) -> String { d.atIndex(i)?.stringValue ?? "" }
        func num(_ i: Int) -> Double { d.atIndex(i)?.doubleValue ?? 0 }
        return Track(state: str(1), title: str(2), artist: str(3), album: str(4),
                     position: num(5), duration: num(6), artworkURL: str(7))
    }

    private func loadArtwork(_ p: Player, _ t: Track) {
        if p == .spotify {
            guard let url = URL(string: t.artworkURL) else { return }
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let data, let img = NSImage(data: data) else { return }
                DispatchQueue.main.async { self?.artwork = img }
            }.resume()
        } else {
            queue.async { [weak self] in
                let src = """
                tell application "Music"
                    try
                        return raw data of artwork 1 of current track
                    end try
                end tell
                """
                guard let d = self?.run(src), let img = NSImage(data: d.data) else { return }
                DispatchQueue.main.async { self?.artwork = img }
            }
        }
    }

    private func command(_ cmd: String) {
        guard let p = player else { return }
        queue.async { [weak self] in
            _ = self?.run("tell application \"\(p.rawValue)\" to \(cmd)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self?.poll() }
        }
    }

    func playPause() {
        isPlaying.toggle()
        command("playpause")
    }

    func next() { command("next track") }
    func previous() { command("previous track") }

    func seek(to seconds: Double) {
        position = seconds
        command("set player position to \(seconds)")
    }

    func launch(_ p: Player) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: p.bundleID) {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
    }

    func activatePlayer() {
        if let p = player { launch(p) }
    }
}
