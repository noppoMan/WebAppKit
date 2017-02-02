# WebAppKit
WebApplicationKit (Router, Middleware etc...) for [Prorsum](https://github.com/noppoMan/Prorsum)

## Features
- [x] Routing
- [x] Middleware

## Available pre installed Middlewares
- ServeStaticMiddleware

## Getting Started

### 1. Create Your SPM Project

```sh
mkdir MyWebKitApp
cd MyWebKitApp
swift package init
```

### 2. Edit Your Package.swift

```swift
import PackageDescription

let package = Package(
    name: "MyWebKitApp",
    dependencies: [
        .Package(url: "https://github.com/noppoMan/WebAppKit.git", majorVersion: 0, minor: 1)
    ]
)
```

### 3. Create main.swift

```sh
touch Sources/main.swift
```
And then , copy and paste following boilerplate to your `main.swift`

**main.swift boilerplate**
```swift
import Prorsum
import WebAppKit
import Foundation

let app = Ace()
var router = Router()

let root = #file.characters
    .split(separator: "/", omittingEmptySubsequences: false)
    .dropLast(1)
    .map { String($0) }
    .joined(separator: "/")

app.use(ServeStaticMiddleware(root: root + "/../public"))

router.use(.get, "/") { request in
    return Response(body: .buffer("Welcome WebAppKit!".data))
}

app.use(router)

app.catch { error in
    switch error {
    case ServeStaticMiddlewareError.resourceNotFound(let path):
        return Response(status: .notFound, body: .buffer("\(path) is not found".data))

    case RouterError.routeNotFound(let path):
        return Response(status: .notFound, body: .buffer("\(path) is not found".data))

    default:
        print(error)
        return Response(status: .internalServerError, body: .buffer("Internal Server Error".data))
    }
}

let server = try! HTTPServer(app.handler)

try! server.bind(host: "0.0.0.0", port: 3000)
print("Server listening at 0.0.0.0:3000")
try! server.listen()

RunLoop.main.run()
```

## 4. Create xcodeproj and Open it with Xcode

```swift
swift package generate-xcodeproj --type=executable
open *.xcodeproj
```

## Run with Xcode

- Select Your Application name from Schema(may be MyWebKitApp)
- Enter `cmd-r` to start up web server

## Run with CLI

```
swift build
.build/debug/YourApplicationNamme
```

## License
WebAppKit is released under the MIT license. See LICENSE for details.
