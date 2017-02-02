import XCTest
@testable import WebAppKit
@testable import Prorsum
import Foundation

class WebAppKitTests: XCTestCase {

    static var allTests : [(String, (WebAppKitTests) -> () throws -> Void)] {
        return [
            ("testServer", testServer),
        ]
    }
    
    func testServer() {
        let app = Ace()
        var router = Router()
        
        router.use(.get, "/") { request in
            return Response(status: .ok)
        }
        
        app.use(router)
        
        let server = try! HTTPServer(app.handler)
        
        go {
            try! server.bind(host: "0.0.0.0", port: 53000)
            print("Server listening at 0.0.0.0:3000")
            try! server.listen()
        }

        var done = false
        
        go {
            sleep(1)
            let url = URL(string: "http://localhost:53000")!
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                let status = (response as! HTTPURLResponse).statusCode
                XCTAssertEqual(status, 200)
                server.terminate()
                done = true
            }
            task.resume()
        }
        
        while done == false {}
    }
}
