import Foundation

enum APIConfiguration {
    #if DEBUG
    // Use Mac's local IP for physical device testing, or localhost for simulator
    #if targetEnvironment(simulator)
    static let baseURL = URL(string: "http://localhost:3000/api/v1")!
    #else
    static let baseURL = URL(string: "http://192.168.1.33:3000/api/v1")!
    #endif
    #else
    static let baseURL = URL(string: "https://group-debt-reconciler.vercel.app/api/v1")!
    #endif

    static let timeoutInterval: TimeInterval = 30
}
