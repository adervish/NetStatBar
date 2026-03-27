import Foundation
import CoreLocation
import CoreWLAN
import Network
import SQLite3

// ── Update this after deploying your Cloudflare Worker ──────────────────────
let workerURL = "https://browser-info.acd.workers.dev"
// ────────────────────────────────────────────────────────────────────────────

struct PingResult {
    let timestamp: Date
    let latency: Double?   // ms; nil = timeout / unreachable
    let bssid: String
    let channel: Int
    let channelBand: String
}

class NetworkMonitor: NSObject, CLLocationManagerDelegate {
    static let shared = NetworkMonitor()
    private override init() { super.init() }

    private var locationManager: CLLocationManager?

    private(set) var pings: [PingResult] = []
    private(set) var publicIP: String = "—"
    private(set) var isp: String = "—"

    // WiFi — SSID/BSSID via CoreWLAN (requires wifi-info entitlement)
    // RSSI/channel updated every second; SSID/BSSID updated every second too
    private(set) var wifiSSID: String = "—"
    private(set) var wifiBSSID: String = "—"
    private(set) var wifiRSSI: Int = 0
    private(set) var wifiChannel: Int = 0
    private(set) var wifiChannelBand: String = "—"
    private(set) var wifiChannelWidth: String = "—"

    // Active WiFi interface discovered via NWPathMonitor
    private var activeWiFiInterface: String = "en0"
    private var pathMonitor: NWPathMonitor?

    var onChange: (() -> Void)?

    private var pingTimer: Timer?
    private var infoTimer: Timer?

    // Dedicated serial queue for all ping NWConnections
    private let pingQueue = DispatchQueue(label: "com.netstatbar.ping", qos: .utility)

    // MARK: – SQLite

    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "com.netstatbar.db", qos: .utility)

    private typealias SQLiteDestructor = @convention(c) (UnsafeMutableRawPointer?) -> Void
    private lazy var SQLITE_TRANSIENT: SQLiteDestructor = unsafeBitCast(-1 as Int, to: SQLiteDestructor.self)

    private func openDatabase() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("NetStatBar")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("measurements.db").path

        dbQueue.sync {
            guard sqlite3_open(path, &self.db) == SQLITE_OK else { return }
            let create = """
                CREATE TABLE IF NOT EXISTS measurements (
                    id            INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp     REAL    NOT NULL,
                    latency_ms    REAL,
                    ssid          TEXT,
                    bssid         TEXT,
                    rssi          INTEGER,
                    channel       INTEGER,
                    channel_band  TEXT,
                    channel_width TEXT,
                    public_ip     TEXT,
                    isp           TEXT
                )
                """
            sqlite3_exec(self.db, create, nil, nil, nil)
            // Migration: add ssid column to databases created before v1.2
            sqlite3_exec(self.db, "ALTER TABLE measurements ADD COLUMN ssid TEXT", nil, nil, nil)
        }

        NSLog("NetStatBar: database at %@", path)
    }

    private func insertMeasurement(latency: Double?) {
        let ssid    = wifiSSID
        let bssid   = wifiBSSID
        let rssi    = wifiRSSI
        let channel = wifiChannel
        let band    = wifiChannelBand
        let width   = wifiChannelWidth
        let ip      = publicIP
        let ispName = isp
        let ts      = Date().timeIntervalSince1970

        dbQueue.async { [weak self] in
            guard let self, let db = self.db else { return }
            let sql = """
                INSERT INTO measurements
                    (timestamp, latency_ms, ssid, bssid, rssi, channel, channel_band, channel_width, public_ip, isp)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            let t = self.SQLITE_TRANSIENT
            sqlite3_bind_double(stmt, 1, ts)
            if let ms = latency { sqlite3_bind_double(stmt, 2, ms) } else { sqlite3_bind_null(stmt, 2) }
            sqlite3_bind_text(stmt, 3, ssid,    -1, t)
            sqlite3_bind_text(stmt, 4, bssid,   -1, t)
            sqlite3_bind_int (stmt, 5, Int32(rssi))
            sqlite3_bind_int (stmt, 6, Int32(channel))
            sqlite3_bind_text(stmt, 7, band,    -1, t)
            sqlite3_bind_text(stmt, 8, width,   -1, t)
            sqlite3_bind_text(stmt, 9, ip,      -1, t)
            sqlite3_bind_text(stmt, 10, ispName, -1, t)
            sqlite3_step(stmt)
        }
    }

    // MARK: – Lifecycle

    func start() {
        openDatabase()
        startPathMonitor()
        requestLocationPermission()
        doPing()
        fetchNetworkInfo()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.doPing()
        }
        infoTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.fetchNetworkInfo()
        }
    }

    // MARK: – Location permission
    // On macOS, granting location access unlocks CoreWLAN SSID/BSSID.
    // The permission prompt appears once; the system remembers the choice.

    private func requestLocationPermission() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Re-read WiFi info now that permission status has changed
        readWiFiInfo()
        onChange?()
    }

    // MARK: – Path monitoring

    private func startPathMonitor() {
        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            let wifiIface = path.availableInterfaces.first { $0.type == .wifi }
            DispatchQueue.main.async {
                self?.activeWiFiInterface = wifiIface?.name ?? "en0"
            }
        }
        pathMonitor?.start(queue: DispatchQueue.global(qos: .utility))
    }

    // MARK: – WiFi (called on main thread from doPing every second)

    private func readWiFiInfo() {
        let iface = CWWiFiClient.shared().interface(withName: activeWiFiInterface)
        wifiSSID  = iface?.ssid() ?? "—"
        wifiBSSID = iface?.bssid() ?? "—"
        wifiRSSI  = iface?.rssiValue() ?? 0

        if let ch = iface?.wlanChannel() {
            wifiChannel = ch.channelNumber
            switch ch.channelBand {
            case .band2GHz: wifiChannelBand = "2.4 GHz"
            case .band5GHz: wifiChannelBand = "5 GHz"
            case .band6GHz: wifiChannelBand = "6 GHz"
            default:        wifiChannelBand = "—"
            }
            switch ch.channelWidth {
            case .width20MHz:  wifiChannelWidth = "20 MHz"
            case .width40MHz:  wifiChannelWidth = "40 MHz"
            case .width80MHz:  wifiChannelWidth = "80 MHz"
            case .width160MHz: wifiChannelWidth = "160 MHz"
            default:           wifiChannelWidth = "—"
            }
        } else {
            wifiChannel = 0
            wifiChannelBand = "—"
            wifiChannelWidth = "—"
        }
    }

    // MARK: – Ping
    // Uses a TCP connection to 1.1.1.1:80 instead of ICMP so it works inside
    // the App Sandbox (raw sockets are not permitted in sandboxed apps).
    // TCP round-trip to a nearby CDN edge is a reliable latency proxy.

    private func doPing() {
        readWiFiInfo()   // main thread — safe for CoreWLAN

        let connection = NWConnection(host: "1.1.1.1", port: 80, using: .tcp)
        let start = Date()
        var done = false   // guarded by pingQueue (serial)

        connection.stateUpdateHandler = { [weak self] state in
            self?.pingQueue.async {
                guard !done else { return }
                switch state {
                case .ready:
                    done = true
                    connection.cancel()
                    self?.record(Date().timeIntervalSince(start) * 1000)
                case .failed:
                    done = true
                    connection.cancel()
                    self?.record(nil)
                default:
                    break
                }
            }
        }

        connection.start(queue: pingQueue)

        // 2-second timeout
        pingQueue.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard !done else { return }
            done = true
            connection.cancel()
            self?.record(nil)
        }
    }

    private func record(_ latency: Double?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            pings.append(PingResult(
                timestamp: Date(),
                latency: latency,
                bssid: wifiBSSID,
                channel: wifiChannel,
                channelBand: wifiChannelBand
            ))
            if pings.count > 100 { pings.removeFirst(pings.count - 100) }
            insertMeasurement(latency: latency)
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
