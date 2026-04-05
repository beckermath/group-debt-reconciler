import Foundation

struct DataResponse<T: Decodable>: Decodable {
    let data: T
}

struct ErrorResponse: Decodable {
    let error: String
}
