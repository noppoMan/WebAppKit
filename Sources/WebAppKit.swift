import Prorsum
import Foundation

public enum Chainer {
    case respond(to: Response)
    case next
}

public typealias Respond = (Request) throws -> Response

public protocol Middleware {
    func respond(to request: Request) throws -> Chainer
}

extension Collection where Self.Iterator.Element == Middleware {
    public func chain(_ request: Request) throws -> Response? {
        for middleware in self.reversed() {
            switch try middleware.respond(to: request) {
            case .respond(to: let response):
                return response
            case .next:
                continue
            }
        }
        
        return nil
    }
}

protocol Route {
    var path: String { get }
    var regexp: Regex { get }
    var paramKeys: [String] { get }
    var method: Request.Method { get }
    var handler: Respond { get }
    var middlewares: [Middleware] { get }
    
    func respond(_ request: Request) throws -> Response
}

extension Route {
    func params(_ request: Request) -> [String: String] {
        guard let path = request.path else {
            return [:]
        }
        
        var parameters: [String: String] = [:]
        
        let values = regexp.groups(path)
        
        for (index, key) in paramKeys.enumerated() {
            parameters[key] = values[index]
        }
        
        return parameters
    }
}

struct BasicRoute: Route {
    let path: String
    let regexp: Regex
    let method: Request.Method
    let handler: Respond
    let paramKeys: [String]
    let middlewares: [Middleware]
    
    init(method: Request.Method, path: String, middlewares: [Middleware] = [], handler: @escaping Respond){
        let parameterRegularExpression = try! Regex(pattern: ":([[:alnum:]_]+)")
        let pattern = parameterRegularExpression.replace(path, withTemplate: "([[:alnum:]_-]+)")
        
        self.method = method
        self.path = path
        self.regexp = try! Regex(pattern: "^" + pattern + "$")
        self.paramKeys = parameterRegularExpression.groups(path)
        self.middlewares = middlewares
        self.handler = handler
    }
    
    func respond(_ request: Request) throws -> Response {
        return try handler(request)
    }
}

public enum RouterError: Error {
    case routeNotFound(String)
}

public struct Router {
    var routes = [Route]()
    
    public init() {}
    
    public mutating func use(_ method: Request.Method, _ path: String, _ handler: @escaping (Request) throws -> Response) {
        let route = BasicRoute(method: method, path: path, handler: handler)
        routes.append(route)
    }
    
    func matchedRoute(for request: Request) -> (Route, Request)? {
        guard let path = request.path else {
            return nil
        }
        
        //let request = request
        for route in routes {
            if route.regexp.matches(path) && request.method == route.method {
                var request = request
                request.params = route.params(request)
                return (route, request)
            }
        }
        
        return nil
    }
}

public final class Ace {
    
    var middlewares = [Middleware]()
    
    var routers = [Router]()
    
    var catchHandler: ((Error) throws -> Response)?
    
    public init() {}
    
    public func use(_ middleware: Middleware){
        self.middlewares.append(middleware)
    }
    
    public func use(_ router: Router) {
        self.routers.append(router)
    }
    
    public func `catch`(_ handler: @escaping (Error) throws -> Response) {
        self.catchHandler = handler
    }
    
    func serialize(_ request: Request, _ response: Response, _ writer: ResponrWriter) throws {
        var response = response
        response.headers["Server"] = "Prosum"
        
        if response.contentType == nil {
            response.contentType = mediaType(forFileExtension: "html")
        }
        
        print(response)
        
        try writer.serialize(response)
        
        if !request.isKeepAlive {
            writer.close()
        }
    }
    
    public func handler(_ request: Request, _ writer: ResponrWriter) {
        do {
            if let response = try middlewares.chain(request) {
                try serialize(request, response, writer)
                return
            }
            
            for router in routers {
                if let (route, newRequest) = router.matchedRoute(for: request) {
                    try serialize(request, route.respond(newRequest), writer)
                    return
                }
            }
            
            // 404
            throw RouterError.routeNotFound(request.path ?? "/")
            
        } catch {
            do {
                if let response = try self.catchHandler?(error) {
                    try serialize(request, response, writer)
                }
            } catch {
                print(error)
                writer.close()
            }
        }
    }
}

extension Request {
    var params: [String: Any]? {
        get {
            return self.storage["params"] as? [String: Any]
        }
        
        set {
            self.storage["params"] = newValue
        }
    }
}

extension Request.Method: CustomStringConvertible {
    public var description: String {
        switch self {
        case .delete:            return "DELETE"
        case .get:               return "GET"
        case .head:              return "HEAD"
        case .post:              return "POST"
        case .put:               return "PUT"
        case .connect:           return "CONNECT"
        case .options:           return "OPTIONS"
        case .trace:             return "TRACE"
        case .patch:             return "PATCH"
        case .other(let method): return method.uppercased()
        }
    }
}

extension Request.Method: Hashable {
    public var hashValue: Int {
        switch self {
        case .delete:            return 0
        case .get:               return 1
        case .head:              return 2
        case .post:              return 3
        case .put:               return 4
        case .connect:           return 5
        case .options:           return 6
        case .trace:             return 7
        case .patch:             return 8
        case .other(let method): return 9 + method.hashValue
        }
    }
}

public func ==(lhs: Request.Method, rhs: Request.Method) -> Bool {
    return lhs.description == rhs.description
}


public var __dirname: String {
    return #file.characters
        .split(separator: "/", omittingEmptySubsequences: false)
        .dropLast(1)
        .map { String($0) }
        .joined(separator: "/")
}
