import Foundation

enum ExpensesEndpoint {
    static func list(groupId: String) -> Endpoint {
        Endpoint(path: "groups/\(groupId)/expenses")
    }

    static func create(groupId: String, description: String, amount: Double, paidBy: String, splitWith: [String], splitMode: String = "equal") -> Endpoint {
        struct Body: Encodable {
            let description: String
            let amount: Double
            let paidBy: String
            let splitWith: [String]
            let splitMode: String
        }
        return Endpoint(
            path: "groups/\(groupId)/expenses",
            method: .post,
            body: Body(description: description, amount: amount, paidBy: paidBy, splitWith: splitWith, splitMode: splitMode)
        )
    }

    static func delete(groupId: String, expenseId: String) -> Endpoint {
        Endpoint(path: "groups/\(groupId)/expenses/\(expenseId)", method: .delete)
    }
}
