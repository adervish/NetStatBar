import Foundation

// ── Update this after deploying your Cloudflare Worker ──────────────────────
let workerURL = "https://browser-info.acd.workers.dev"
// ────────────────────────────────────────────────────────────────────────────

struct PingResult {
    let timestamp: Date
    let latency: Double?   // ms; nil = timeout / unreachable
}

class NetworkMonitor {
    static let shared = NetworkMonitor()
    private init() {}

    private(set) var pings: [PingResult] = []
    private(set) var publicIP: String = "—"
    private(set) var isp: String = "—"

    var onChange: (() -> Void)?

    private var pingTimer: Timer?
    private var infoTimer: Timer?

    func start() {
        doPing()
        fetchNetworkInfo()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.doPing()
        }
        infoTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.fetchNetworkInfo()
        }
    }

    // MARK: – Ping

    private func doPing() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/sbin/ping")
            process.arguments = ["-c", "1", "-t", "2", "1.1.1.1"]

            let stdout = Pipe()
            process.standardOutput = stdout
            process.standardError  = Pipe()

            do { try process.run() } catch { self?.record(nil); return }
            process.waitUntilExit()

            let output = String(
                data: stdout.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""

            // Matches "time=12.3 ms" and "time<1.000 ms"
            var latency: Double? = nil
            let pattern = #"time[<=](\d+\.?\d*)\s*ms"#
            if let re = try? NSRegularExpression(pattern: pattern),
               let m  = re.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
               let r  = Range(m.range(at: 1), in: output) {
                latency = Double(String(output[r]))
            }
            self?.record(latency)
        }
    }

    private func record(_ latency: Double?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            pings.append(PingResult(timestamp: Date(), latency: latency))
            if pings.count > 100 { pings.removeFirst(pings.count - 100) }
            onChange?()
        }
    }

    var recentPings: [PingResult] {
        let cutoff = Date().addingTimeInterval(-10)
        return pings.filter { $0.timestamp >= cutoff }
    }

    // MARK: – Network info

    func fetchNetworkInfo() {
        guard let url = URL(string: workerURL + "?json") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return }
            DispatchQueue.main.async {
                self?.publicIP = json["ip"] as? String ?? "—"
                if let cf = json["cf"] as? [String: Any] {
                    self?.isp = cf["asOrganization"] as? String ?? "—"
                }
                self?.onChange?()
            }
        }.resume()
    }

    // MARK: – Stats

    /// 0.0 = bad (red)  →  1.0 = good (green) — based on last 10 seconds
    var quality: Double {
        let recent = recentPings
        guard !recent.isEmpty else { return 1.0 }
        let lossRate  = Double(recent.filter { $0.latency == nil }.count) / Double(recent.count)
        let latencies = recent.compactMap { $0.latency }
        let avg       = latencies.isEmpty ? 300.0 : latencies.reduce(0, +) / Double(latencies.count)
        let latScore  = max(0.0, 1.0 - avg / 300.0)
        let lossScore = max(0.0, 1.0 - lossRate / 0.5)
        return min(latScore, lossScore)
    }

    var avgLatencyString: String {
        let l = recentPings.compactMap { $0.latency }
        guard !l.isEmpty else { return "—" }
        return String(format: "%.0f ms", l.reduce(0, +) / Double(l.count))
    }

    var packetLossString: String {
        let recent = recentPings
        guard !recent.isEmpty else { return "—" }
        let pct = Double(recent.filter { $0.latency == nil }.count) / Double(recent.count) * 100
        return String(format: "%.0f%%", pct)
    }
}
