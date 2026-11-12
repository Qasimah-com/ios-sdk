import Foundation

public final class PlansClient {
    public static let timeout: TimeInterval = 5
    public static let plansPath = "/api/v1/widget/plans"

    private let session: URLSession

    public init(session: URLSession? = nil) {
        self.session = session ?? PlansClient.makeSession()
    }

    public static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }

    public static func request(amount: Decimal, publicKey: PublicKey, apiBaseURL: URL? = nil, language: QasimhaLanguage) -> URLRequest? {
        guard let amountParameter = Money.amountParameter(amount) else { return nil }
        let base: URL
        if let override = apiBaseURL {
            guard let normalized = QasimhaEnvironment.normalizedAPIBaseURL(override) else { return nil }
            base = normalized
        } else {
            base = publicKey.apiBaseURL
        }
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: true) else { return nil }
        components.path += plansPath
        components.queryItems = [
            URLQueryItem(name: "amount", value: amountParameter),
            URLQueryItem(name: "currency", value: "SAR"),
            URLQueryItem(name: "lang", value: language.rawValue),
        ]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.httpShouldHandleCookies = false
        request.setValue(publicKey.rawValue, forHTTPHeaderField: "X-Public-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("qasimha-checkout-ios/" + QasimhaCheckout.version, forHTTPHeaderField: "User-Agent")
        return request
    }

    @discardableResult
    public func fetch(amount: Decimal, publicKey: PublicKey, apiBaseURL: URL? = nil, language: QasimhaLanguage,
                      completion: @escaping (PromoPlans?) -> Void) -> URLSessionDataTask? {
        guard let request = PlansClient.request(amount: amount, publicKey: publicKey, apiBaseURL: apiBaseURL, language: language) else {
            completion(nil)
            return nil
        }
        let task = session.dataTask(with: request) { data, response, error in
            guard error == nil,
                  let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let data = data else {
                completion(nil)
                return
            }
            completion(PlansResponse.parse(data, amount: amount))
        }
        task.resume()
        return task
    }
}
