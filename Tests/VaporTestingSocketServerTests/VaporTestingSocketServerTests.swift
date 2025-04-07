import Testing
import Vapor
import VaporTesting
import VaporTestingSocketServer

@Suite
struct SocketServerTests {
    @Test
    func applicationTestableWithSocketServer() async throws {
        try await VaporTesting.withApp { app in
            try await withTemporarySocket { tempSocket in
                try app.register(collection: HelloController())

                try await app.testing(method: .unixDomainSocket(path: tempSocket.path))
                    .test(.GET, "hello", afterResponse: { res async throws in
                        var body = res.body
                        let bodyString = body.readString(length: body.readableBytes)
                        #expect(bodyString == "hello")
                        #expect(res.status == .ok)
                    })
            }
        }
    }

    @Test
    func applicationTestableWithSocketServerWithClientUsedWithinApplication() async throws {
        try await VaporTesting.withApp { app in
            try await withTemporarySocket { tempSocket in
                try app.register(collection: HelloController())
                try app.register(collection: IndirectHelloController(baseURL: tempSocket.url))

                try await app.testing(method: .unixDomainSocket(path: tempSocket.path))
                    .test(.GET, "indirect-hello", afterResponse: { res async throws in
                        var body = res.body
                        let bodyString = body.readString(length: body.readableBytes)
                        #expect(bodyString == "hello")
                        #expect(res.status == .ok)
                    })
            }
        }
    }
}

private struct HelloController: RouteCollection {
    func boot(routes: any Vapor.RoutesBuilder) throws {
        routes.get("hello", use: { _ in
            "hello"
        })
    }
}

private struct IndirectHelloController: RouteCollection {
    let baseURL: URL

    func boot(routes: any Vapor.RoutesBuilder) throws {
        routes.get("indirect-hello", use: { req in
            let url = baseURL.appendingPathComponent("hello")
            return req.client.get(URI(string: url.absoluteString))
        })
    }
}
