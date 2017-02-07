//
//  ServeStaticMiddleware.swift
//  WebAppKit
//
//  Created by Yuki Takei on 2017/02/02.
//
//

import Prorsum
import Foundation

public enum ServeStaticMiddlewareError: Error {
    case resourceNotFound(String)
}

public struct ServeStaticMiddleware: Middleware {
    
    let root: String
    
    public init(root: String){
        self.root = root
    }
    
    public func respond(to request: Request, response: Response) throws -> Chainer {
        var response = response
        
        let path = request.path ?? "/"
        
        do {
            let pathes = path.components(separatedBy: "/")
            
            if let ext = pathes.last?.components(separatedBy: ".").last, let contentType = mediaType(forFileExtension: ext) {
                let data = try Data(contentsOf: URL(string: "file://\(root)\(path)")!)
                
                response.headers["Server"] = "Prorsum Micro HTTP Server"
                
                var response = Response(
                    headers: ["Server": "Prorsum Micro HTTP Server"],
                    body: .buffer(data)
                )
                
                response.contentType = contentType
                response.body = .buffer(data)
                
                return .respond(to: response)
            }
            
            return .next(response)
        } catch {
            throw ServeStaticMiddlewareError.resourceNotFound(path)
        }
    }
}
