import CoreLocation
import Foundation

/// Current weather from Open-Meteo (no API key). Uses the Mac's location, or a city set in Settings.
final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WeatherService()

    @Published var temperature: Double?
    @Published var high: Double?
    @Published var low: Double?
    @Published var code = 0
    @Published var isDay = true
    @Published var city = ""
    @Published var error: String?

    private let manager = CLLocationManager()
    private var timer: Timer?
    private var lastCityQuery = ""
    private var lastUnit = ""

    func start() {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in self?.refresh() }
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let d = UserDefaults.standard
            let q = d.string(forKey: Prefs.weatherCity) ?? "", u = d.string(forKey: Prefs.weatherUnit) ?? ""
            if q != self.lastCityQuery || u != self.lastUnit { self.refresh() }
        }
    }

    func refresh() {
        let d = UserDefaults.standard
        lastCityQuery = d.string(forKey: Prefs.weatherCity) ?? ""
        lastUnit = d.string(forKey: Prefs.weatherUnit) ?? "C"
        let city = lastCityQuery.trimmingCharacters(in: .whitespaces)
        if !city.isEmpty {
            geocode(city)
            return
        }
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .denied, .restricted: error = "Location off — set a city in Settings"
        default: manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorized {
            manager.requestLocation()
        } else if manager.authorizationStatus == .denied {
            error = "Location off — set a city in Settings"
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last, (UserDefaults.standard.string(forKey: Prefs.weatherCity) ?? "").isEmpty else { return }
        fetch(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
        CLGeocoder().reverseGeocodeLocation(loc) { [weak self] marks, _ in
            if let name = marks?.first?.locality { DispatchQueue.main.async { self?.city = name } }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { self.error = "Couldn't get location" }
    }

    private struct GeoResponse: Decodable {
        struct Result: Decodable { let name: String; let latitude: Double; let longitude: Double }
        let results: [Result]?
    }

    private func geocode(_ name: String) {
        var comps = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        comps.queryItems = [.init(name: "name", value: name), .init(name: "count", value: "1")]
        URLSession.shared.dataTask(with: comps.url!) { [weak self] data, _, _ in
            guard let data, let r = try? JSONDecoder().decode(GeoResponse.self, from: data), let first = r.results?.first else {
                DispatchQueue.main.async { self?.error = "City not found" }
                return
            }
            DispatchQueue.main.async { self?.city = first.name }
            self?.fetch(lat: first.latitude, lon: first.longitude)
        }.resume()
    }

    private struct ForecastResponse: Decodable {
        struct Current: Decodable { let temperature_2m: Double; let weather_code: Int; let is_day: Int }
        struct Daily: Decodable { let temperature_2m_max: [Double]; let temperature_2m_min: [Double] }
        let current: Current
        let daily: Daily
    }

    private func fetch(lat: Double, lon: Double) {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            .init(name: "latitude", value: String(lat)),
            .init(name: "longitude", value: String(lon)),
            .init(name: "current", value: "temperature_2m,weather_code,is_day"),
            .init(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
            .init(name: "forecast_days", value: "1"),
            .init(name: "timezone", value: "auto"),
        ]
        if lastUnit == "F" { comps.queryItems?.append(.init(name: "temperature_unit", value: "fahrenheit")) }
        URLSession.shared.dataTask(with: comps.url!) { [weak self] data, _, _ in
            guard let data, let r = try? JSONDecoder().decode(ForecastResponse.self, from: data) else {
                DispatchQueue.main.async { self?.error = "Weather unavailable" }
                return
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.error = nil
                self.temperature = r.current.temperature_2m
                self.code = r.current.weather_code
                self.isDay = r.current.is_day == 1
                self.high = r.daily.temperature_2m_max.first
                self.low = r.daily.temperature_2m_min.first
            }
        }.resume()
    }

    var symbol: String {
        switch code {
        case 0: isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51...57: "cloud.drizzle.fill"
        case 61...67, 80...82: "cloud.rain.fill"
        case 71...77, 85, 86: "cloud.snow.fill"
        case 95...99: "cloud.bolt.rain.fill"
        default: "cloud.fill"
        }
    }

    var summary: String {
        switch code {
        case 0: "Clear"
        case 1, 2: "Partly cloudy"
        case 3: "Overcast"
        case 45, 48: "Fog"
        case 51...57: "Drizzle"
        case 61...67, 80...82: "Rain"
        case 71...77, 85, 86: "Snow"
        case 95...99: "Thunderstorm"
        default: "—"
        }
    }
}
