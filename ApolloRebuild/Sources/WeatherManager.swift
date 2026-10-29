import Foundation

// WeatherManager - fetches weather data for the user's location
// Reconstructed from apollo-base 1.15.11 binary analysis.

class WeatherManager {
    
    static let shared = WeatherManager()
    
    private var currentWeather: String?
    
    private init() {}
    
    func fetchWeather(forLocation location: String, completion: @escaping (String?) -> Void) {
        // Fetch weather from OpenWeatherMap
        let apiKey = "your_openweathermap_api_key"
        let encodedLocation = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? location
        let url = URL(string: "https://api.openweathermap.org/data/2.5/weather?q=\(encodedLocation)&appid=\(apiKey)&units=imperial")!
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    if let main = json?["main"] as? [String: Any],
                       let temp = main["temp"] as? Double,
                       let weather = json?["weather"] as? [[String: Any]],
                       let description = weather.first?["description"] as? String {
                        let weatherString = "\(description.capitalized), \(Int(temp))°F"
                        DispatchQueue.main.async {
                            self.currentWeather = weatherString
                            completion(weatherString)
                        }
                        return
                    }
                } catch {
                    print("Weather fetch failed: \(error)")
                }
            }
            
            DispatchQueue.main.async {
                completion(nil)
            }
        }.resume()
    }
    
    var weather: String? {
        return self.currentWeather
    }
}
