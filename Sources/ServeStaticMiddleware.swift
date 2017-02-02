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
    
    public func respond(to request: Request) throws -> Chainer {
        let path = request.path ?? "/"
        
        do {
            let pathes = path.components(separatedBy: "/")
            
            if let ext = pathes.last?.components(separatedBy: ".").last, let contentType = mediaType(forFileExtension: ext) {
                let data = try Data(contentsOf: URL(string: "file://\(root)\(path)")!)
                var response = Response(
                    headers: ["Server": "Prorsum Micro HTTP Server"],
                    body: .buffer(data)
                )
                
                response.contentType = contentType
                
                return .respond(to: response)
            }
            
            return .next
        } catch {
            throw ServeStaticMiddlewareError.resourceNotFound(path)
        }
    }
}
