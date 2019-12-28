//  TestAPIClient.swift
//
//  Created by Aaron Thompson on 12/27/19.
//

import Foundation

public class TestAPIClient: ServerAPIClient {
    
    private static let _BaseURLString = "https://localhost/"
    
    private var _personalCredentials = PersonalCredentials(expiry: "",
                                                           tokenType: "",
                                                           accessToken: "",
                                                           client: "",
                                                           uid: "")
    private var _teamCredentials = TeamCredentials(apiKey: "",
                                                   accessToken: "")
    
    private var _currentCredentials: ServerCredentials? { return _teamCredentials.isValid ? _teamCredentials : _personalCredentials }
    
    private let _queue = DispatchQueue(label: "TestAPIClient._queue")
    
    public var responseJSONPath: String?
    public var responseError: ServerOperationError?
    
    public init() {}
    
    // MARK: - ServerAPIClient
    
    public func invalidateCredentials() {
        PersonalCredentials.invalidate()
        TeamCredentials.invalidate()
    }
    
    public func buildAPIURL(for urlComponentString: String) -> URL {
        return URL(fileURLWithPath: responseJSONPath ?? urlComponentString, relativeTo: Bundle(for: TestAPIClient.self).resourceURL)
    }
    
    public func performBasicOperation(withURL url: URL,
                                      httpMethod: HTTPMethod,
                                      completion: @escaping (ServerOperationError?) -> Void)
    {
        _queue.async { completion(self.responseError) }
    }
    
    public func performJSONOperation<T>(
        withURL url: URL,
        httpMethod: HTTPMethod,
        httpBodyDict: [AnyHashable: Any]?,
        responseObjectRootKey: String? = nil,
        completion: @escaping (Result<T>) -> Void) where T: Codable
    {
        let result: Result<T> = _loadResponseJSON(responseObjectRootKey: responseObjectRootKey)
        
        _queue.async { completion(result) }
    }
    
    public func performDataUploadOperation(
        withURL url: URL,
        httpMethod: HTTPMethod,
        dataURL: URL,
        extraHeaders: [String: Any]?,
        progressHandler: ProgressHandler?,
        completion: @escaping (ServerOperationError?) -> Void)
    {
        _queue.async { completion(self.responseError) }
    }
    
    public func performDataDownloadOperation(
        withURL url: URL,
        httpMethod: HTTPMethod,
        destinationURL: URL,
        extraHeaders: [String: Any]?,
        progressHandler: ProgressHandler?,
        completion: @escaping (ServerOperationError?) -> Void)
    {
        _queue.async { completion(self.responseError) }
    }
    
    public var isValid: Bool { return _currentCredentials?.isValid ?? false }
    
    public func buildURLRequest(url: URL, httpMethod: HTTPMethod, extraHeaders: [String: Any]?) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod.rawValue
        return request
    }
    
    // MARK: - Private
    
    private func _loadResponseJSON() -> Any {
        guard let jsonPath = responseJSONPath else { fatalError("Must specify a responseJSONPath") }
        
        let jsonData = try! Data(contentsOf: URL(fileURLWithPath: jsonPath))
        
        return try! JSONSerialization.jsonObject(with: jsonData, options: [])
    }
    
    private func _errorFromJSONObject(_ jsonObject: Any) -> ServerOperationError? {
        guard let jsonDict = jsonObject as? [String: Any] else { return nil }
        
        if let success = jsonDict["success"] as? Bool, success == true {
            return nil
        }
        
        if let messages = jsonDict["errors"] as? [String] {
            return ServerOperationError.genericErrorString(messages.joined(separator: ", "))
        } else {
            return ServerOperationError.genericErrorString("Unknown error from \(jsonDict)")
        }
    }
    
    private func _loadResponseJSON<T>(responseObjectRootKey: String? = nil) -> Result<T> where T: Codable {
        guard let jsonPath = responseJSONPath else { fatalError("Must specify a responseJSONPath") }
        
        if let responseError = responseError {
            return Result.failure(responseError)
        }
        
        let jsonURL = buildAPIURL(for: jsonPath)
        let jsonData = try! Data(contentsOf: jsonURL)
        let jsonObject = try! JSONSerialization.jsonObject(with: jsonData, options: [])
        
        if let error = _errorFromJSONObject(jsonObject) {
            return .failure(error)
        }
        
        guard
            let key = responseObjectRootKey,
            let unwrappedJSONObject = (jsonObject as? [String : Any])?[key]
        else { return .success(jsonObject as! T) }
        
        let data = try! JSONSerialization.data(withJSONObject: unwrappedJSONObject, options: [])
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let decodedObject = try! decoder.decode(T.self, from: data)
        
        return Result.success(decodedObject)
    }
    
}
