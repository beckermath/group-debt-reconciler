import Foundation

enum APIConfiguration {
    #if DEBUG
    static let baseURL = URL(string: "http://localhost:3000/api/v1")!
    #else
    static let baseURL = URL(string: "https://group-debt-reconciler.vercel.app/api/v1")!
    #endif

    static let timeoutInterval: TimeInterval = 30
}
