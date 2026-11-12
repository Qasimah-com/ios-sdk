import Foundation
import QasimhaCheckout

struct SessionResponse: Decodable {
    let orderId: String
    let paymentUrl: URL
}

struct OrderResponse: Decodable {
    let orderId: String
    let status: String
    let orderReferenceId: String?
}

enum MerchantServerError: LocalizedError {
    case badResponse(Int)

    var errorDescription: String? {
        switch self {
        case .badResponse(let status): return "merchant server answered \(status)"
        }
    }
}

enum MerchantServerClient {
    static func createSession(amount: Decimal, merchantURL: MerchantURL, completion: @escaping (Result<SessionResponse, Error>) -> Void) {
        var request = URLRequest(url: ExampleConfig.merchantServer.appendingPathComponent("sessions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "amount": NSDecimalNumber(decimal: amount).doubleValue,
            "orderReferenceId": "EXAMPLE-\(Int(Date().timeIntervalSince1970))",
            "merchantUrl": [
                "success": merchantURL.success.absoluteString,
                "failure": merchantURL.failure.absoluteString,
                "cancel": merchantURL.cancel.absoluteString,
            ],
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        perform(request, completion: completion)
    }

    static func order(id: String, completion: @escaping (Result<OrderResponse, Error>) -> Void) {
        let request = URLRequest(url: ExampleConfig.merchantServer.appendingPathComponent("orders/\(id)"))
        perform(request, completion: completion)
    }

    private static func perform<Value: Decodable>(_ request: URLRequest, completion: @escaping (Result<Value, Error>) -> Void) {
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(status), let data = data else {
                completion(.failure(MerchantServerError.badResponse(status)))
                return
            }
            do {
                completion(.success(try JSONDecoder().decode(Value.self, from: data)))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
