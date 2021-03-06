import Prorsum
import Foundation

public enum Chainer {
    case respond(to: Response)
    case next(Request, Response)
}

public typealias Respond = (Request, Response) throws -> Response

public protocol Middleware {
    func respond(to request: Request, response: Response) throws -> Chainer
}

public struct BasicMiddleware: Middleware {
    
    let handler: (Request, Response) throws -> Chainer
    
    public init(_ handler: @escaping (Request, Response) throws -> Chainer){
        self.handler = handler
    }
    
    public func respond(to request: Request, response: Response) throws -> Chainer {
        return try handler(request, response)
    }
}

extension Collection where Self.Iterator.Element == Middleware {
    public func chain(_ request: Request) throws -> Chainer {
        var request = request
        var response = Response()
        
        for middleware in self.reversed() {
            let chainer = try middleware.respond(to: request, response: response)
            switch chainer {
            case .next(let req, let res):
                response = res
                request = req
                continue
            default:
                return chainer
            }
        }
        
        return .next(request, response)
    }
}

protocol Route {
    var path: String { get }
    var regexp: Regex { get }
    var paramKeys: [String] { get }
    var method: Request.Method { get }
    var handler: Respond { get }
    var middlewares: [Middleware] { get }
    
    func respond(_ request: Request, _ response: Response) throws -> Response
}

extension Route {
    public func params(_ request: Request) -> [String: String] {
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
    
    func respond(_ request: Request, _ response: Response) throws -> Response {
        switch try middlewares.chain(request) {
        case .respond(to: let response):
            return response
            
        case .next(let request, let response):
            return try handler(request, response)
        }
    }
}

public enum RouterError: Error {
    case routeNotFound(String)
}

public struct Router {
    var routes = [Route]()
    
    public init() {}
    
    public mutating func use(_ method: Request.Method, _ path: String, _ middlewares: [Middleware] = [], _ handler: @escaping (Request, Response) throws -> Response) {
        let route = BasicRoute(method: method, path: path, middlewares: middlewares, handler: handler)
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
    
    public func use(_ middlewareHandler: @escaping (Request, Response) throws -> Chainer) {
        self.middlewares.append(BasicMiddleware(middlewareHandler))
    }
    
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
        
        try writer.serialize(response)
        
        if !request.isKeepAlive {
            writer.close()
        }
    }
    
    public func handler(_ request: Request, _ writer: ResponrWriter) {
        do {
            let chainer = try middlewares.chain(request)
            switch chainer {
            case .respond(to: let response):
                try serialize(request, response, writer)
                
            case .next(let request, let response):
                for router in routers {
                    if let (route, newRequest) = router.matchedRoute(for: request) {
                        try serialize(request, route.respond(newRequest, response), writer)
                        return
                    }
                }
                
                // 404
                throw RouterError.routeNotFound(request.path ?? "/")
            }
            
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
    public var params: [String: Any]? {
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

extension Response {
    
    public mutating func set(headerKey: String, value: String) {
        self.headers[headerKey] = value
    }
    
    public mutating func set(body data: Data) {
        self.body = .buffer(data)
        self.contentLength = data.count
    }
    
    public mutating func set(body text: String) {
        self.body = .buffer(text.data)
        self.contentLength = text.utf8.count
    }
    
    public mutating func set(body bytes: Bytes) {
        self.body = .buffer(Data.init(bytes: bytes))
        self.contentLength = bytes.count
    }
}

extension Body {
    public func becomeBuffer() -> Data? {
        switch self {
        case .buffer(let data):
            return data
        
        default:
            return nil
        }
    }
}
