import Foundation

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConfiguration.timeoutInterval
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
    }

    // MARK: - Public API

    func request<T: Decodable>(_ endpoint: Endpoint) async throws(APIError) -> T {
        let (data, response) = try await execute(endpoint)
        try mapStatusCode(response, data: data)

        do {
            let wrapped = try decoder.decode(DataResponse<T>.self, from: data)
            return wrapped.data
        } catch {
            throw .decodingError(error)
        }
    }

    func requestNoContent(_ endpoint: Endpoint) async throws(APIError) {
        let (data, response) = try await execute(endpoint)
        try mapStatusCode(response, data: data)
    }

    func uploadMultipart<T: Decodable>(path: String, fileData: Data, fileName: String, mimeType: String) async throws(APIError) -> T {
        let boundary = UUID().uuidString
        var request = URLRequest(url: Endpoint(path: path).url)
        request.httpMethod = "PUT"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = await KeychainService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let data: Data
        let urlResponse: URLResponse
        do {
            (data, urlResponse) = try await session.data(for: request)
        } catch let error as URLError {
            throw .networkError(error)
        } catch {
            throw .networkError(URLError(.unknown))
        }

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw .serverError
        }
        try mapStatusCode(httpResponse, data: data)

        do {
            let wrapped = try decoder.decode(DataResponse<T>.self, from: data)
            return wrapped.data
        } catch {
            throw .decodingError(error)
        }
    }

    // MARK: - Internal

    private func execute(_ endpoint: Endpoint) async throws(APIError) -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: endpoint.url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Attach auth token
        if let token = await KeychainService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = endpoint.body {
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                throw .badRequest("Failed to encode request")
            }
        }

        let data: Data
        let urlResponse: URLResponse
        do {
            (data, urlResponse) = try await session.data(for: request)
        } catch let error as URLError {
            throw .networkError(error)
        } catch {
            throw .networkError(URLError(.unknown))
        }

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw .serverError
        }

        return (data, httpResponse)
    }

    private func mapStatusCode(_ response: HTTPURLResponse, data: Data) throws(APIError) {
        switch response.statusCode {
        case 200...299:
            return
        case 401:
            throw .unauthorized
        case 403:
            let msg = (try? decoder.decode(ErrorResponse.self, from: data))?.error ?? "Forbidden"
            throw .forbidden(msg)
        case 404:
            let msg = (try? decoder.decode(ErrorResponse.self, from: data))?.error ?? "Not found"
            throw .notFound(msg)
        case 400:
            let msg = (try? decoder.decode(ErrorResponse.self, from: data))?.error ?? "Bad request"
            throw .badRequest(msg)
        case 429:
            throw .rateLimited
        default:
            throw .serverError
        }
    }
}

// MARK: - Endpoint

struct Endpoint {
    let url: URL
    let method: HTTPMethod
    let body: (any Encodable)?

    init(path: String, method: HTTPMethod = .get, body: (any Encodable)? = nil) {
        // Use string concatenation to preserve query params (appendingPathComponent encodes ?)
        let baseString = APIConfiguration.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.url = URL(string: "\(baseString)/\(path)")!
        self.method = method
        self.body = body
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}
