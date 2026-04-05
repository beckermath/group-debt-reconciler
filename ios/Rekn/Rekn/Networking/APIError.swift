import Foundation

enum APIError: LocalizedError {
    case networkError(URLError)
    case unauthorized
    case forbidden(String)
    case notFound(String)
    case badRequest(String)
    case rateLimited
    case serverError
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .networkError(let error): error.localizedDescription
        case .unauthorized: "Please sign in again"
        case .forbidden(let msg): msg
        case .notFound(let msg): msg
        case .badRequest(let msg): msg
        case .rateLimited: "Too many requests. Please slow down."
        case .serverError: "Something went wrong. Please try again."
        case .decodingError: "Unexpected response from server"
        }
    }
}
