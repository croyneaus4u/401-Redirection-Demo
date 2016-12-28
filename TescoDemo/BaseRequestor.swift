//
//  BaseRequestor.swift
//  TescoDemo
//
//  Copyright © 2016 Lab kumar. All rights reserved.
//  Created by Lab kumar on 27/12/16.



import Foundation

enum RequestMethodType: String {
    case GET = "GET", POST = "POST", PUT = "PUT", DELETE = "DELETE"
}

typealias NetworkSuccessHandler = (AnyObject?) -> Void
typealias NetworkFailureHandler = (NSError?) -> Void
typealias NetworkCompletionHandler = (_ success: Bool, _ object: AnyObject?) -> Void

typealias RetryTask = (Void) -> Void

class BaseRequestor: NSObject {
    
    // MARK:- Singleton Initiation
    static let sharedInstance = BaseRequestor()
    fileprivate override init() {
        //
    }
    
    // MARK:- Variables
    var dataTask: URLSessionDataTask?   // The Data Task that makes API Call
    var retryTaskArray = [RetryTask]()  // The Array that holds all the Task to be retried
    var isUpdatingToken = false         // variable indicating whether <AUTH_TOKEN> is being updated currently
    
    let AUTH_KEY_NAME = "AUTH_TOKEN"    // The Key Name used to save <AUTH_TOKEN> to Userdefaults
    
    // MARK:- Request Header & Configuration
    /* Getting Default Headers to be used for the Request */
    func defaultHeaders () -> [String: String] {
        if let token = getAuthToken() {
            return ["Accept" : "application/json", "Access-Token": token]
        }
        
        return ["Accept" : "application/json"]
    }
    
    func setAuthToken (authToken: String) {
        UserDefaults.standard.set(authToken, forKey: AUTH_KEY_NAME)
        UserDefaults.standard.synchronize()
    }
    
    func getAuthToken () -> String? {
        return UserDefaults.standard.value(forKey: AUTH_KEY_NAME) as? String
    }
    
    /* Getting the URL Configuration */
    func urlConfiguration () -> URLSessionConfiguration {
        return URLSessionConfiguration.default
    }
    
    // MARK:- Generic request
    // Handles Making call to Server And Creating the Retry Queue
    func makeRequestWithparameters (_ method: RequestMethodType, urlString: String, success: NetworkSuccessHandler?, failure: NetworkFailureHandler?) {
        
        print("\nRequestHeaders:>> \(defaultHeaders())")
        print("\nRequestURL:>> \(urlString)")
        
        guard let url = URL(string: urlString) else {
            failure?(nil)
            return
        }
        
        let retryTask: RetryTask = { [weak self] in
            guard let strongSelf  = self else { return }
            strongSelf.makeRequestWithparameters(method, urlString: urlString, success: success, failure: failure)
        }
        
        if isUpdatingToken {
            retryTaskArray.append(retryTask)
            return
        }
        
        
        // make API Request
        let request = NSMutableURLRequest(url: url)
        request.allHTTPHeaderFields = defaultHeaders()
        request.httpMethod = method.rawValue
        
        dataTask = URLSession(configuration: urlConfiguration()).dataTask(with: request as URLRequest, completionHandler: { [weak self] (data, response, error) in
            guard let strongSelf  = self else { return }
            DispatchQueue.main.async(execute: {
                if let response = response as? HTTPURLResponse, response.statusCode == 401 {
                    strongSelf.retryTaskArray.append(retryTask)
                    strongSelf.updateAuthToken()
                } else if error != nil {
                    failure?(error as NSError?)
                } else if let _ = data, let response = response as? HTTPURLResponse, 200...299 ~= response.statusCode {
                    do {
                        let serialized = try JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                        //print(serialized)
                        success?(serialized as AnyObject?)
                    } catch {
                        print("exception in serializing object")
                        failure?(nil)
                    }
                } else {
                    failure?(nil)
                }
            })
        })
        
        dataTask?.resume()
    }
    
    /* Updating the <AUTH_TOKEN> when encountered 401 */
    func updateAuthToken () {
        isUpdatingToken = true
        
        // Make the API Call for updating <AUTH_TOKEN>
        
        getAuthTokenFromServer { [weak self] (updatedAuthToken) in
            guard let strongSelf  = self else { return }
            
            // Then update the token by calling
            strongSelf.setAuthToken(authToken: updatedAuthToken)
            
            // Then Call the Retry tasks
            let tasksCopy = strongSelf.retryTaskArray
            strongSelf.retryTaskArray.removeAll()
            
            // set isUpdatingToken as false
            strongSelf.isUpdatingToken = false
            
            let _ = tasksCopy.map({$0()})
        }
    }
    
    /* Getting Updated <AUTH_TOKEN> from server */
    func getAuthTokenFromServer (completionHandler: ((String) -> Void)?) {
        // Make Asynchronous Call to server here.
        // On Successfull completion of the API call, call the completionHandler
        
        completionHandler?("UPDATED_AUTH_TOKEN_FROM_SERVER")
    }
    
    // make GET Request
    func makeGETRequestWithparameters (_ urlString: String, success: NetworkSuccessHandler?, failure: NetworkFailureHandler?) {
        makeRequestWithparameters(.GET, urlString: urlString, success: success, failure: failure)
    }
}
