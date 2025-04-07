//
//  VaporTestingSocketServer.swift
//  VaporTestingSocketServer
//
//  Created by Annalise Mariottini on 4/6/25.
//

import AsyncHTTPClient
import NIOCore
import NIOTransportServices
import Vapor
import VaporTesting

// for TestingHTTPResponse init
@testable import VaporTestUtils

extension Application {
    struct SocketServer: TestingApplicationTester {
        let app: Application
        let socketPath: String

        init(app: Application, socketPath: String) throws {
            self.app = app
            self.socketPath = socketPath
        }

        func performTest(request: TestingHTTPRequest) async throws -> TestingHTTPResponse {
            // modified version of Application.Live from VaporTestUtils
            try await app.server.start(address: .unixDomainSocket(path: socketPath))
            let client = HTTPClient(eventLoopGroup: NIOTSEventLoopGroup.singleton)

            do {
                var path = request.url.path
                path = path.hasPrefix("/") ? path : "/\(path)"

                guard let url = URL(httpURLWithSocketPath: socketPath, uri: path) else {
                    throw Abort(.internalServerError, reason: "Failed to create URL for socket path")
                }
                var clientRequest = HTTPClientRequest(url: url.absoluteString)
                clientRequest.method = request.method
                clientRequest.headers = request.headers
                clientRequest.body = .bytes(request.body)
                let response = try await client.execute(clientRequest, timeout: .seconds(30))
                // Collect up to 1MB
                let responseBody = try await response.body.collect(upTo: 1024 * 1024)
                try await client.shutdown()
                await app.server.shutdown()
                return TestingHTTPResponse(
                    status: response.status,
                    headers: response.headers,
                    body: responseBody
                )
            } catch {
                try? await client.shutdown()
                await app.server.shutdown()
                throw error
            }
        }
    }
}

public extension Application {
    /// Testing method for socket servers.
    enum SocketServerMethod {
        case unixDomainSocket(path: String)
    }

    /// Returns an application tester for the passed server testing method.
    func testing(method: SocketServerMethod) throws -> TestingApplicationTester {
        switch method {
        case let .unixDomainSocket(path):
            return try SocketServer(app: self, socketPath: path)
        }
    }
}
