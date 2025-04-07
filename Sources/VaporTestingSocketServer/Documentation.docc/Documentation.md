# ``VaporTestingSocketServer``

A supplement to `VaporTesting` to work with an application over UNIX domain sockets (UDS).

## Overview

The [vapor](https://github.com/vapor/vapor) library already ships with a very useful `VaporTesting` library that supports "in-memory" and "live" TCP server testing.
However, this SDK does not support server testing over UDS.
This package was created to fill this need.

### Why use UDS for Vapor server testing?

When testing a Vapor server, there's often a need to stub requests made to endpoints made to external services.
One easy way to achieve this is to create a `RouteCollection` for that external service for testing purposes and add it to the application being unit tested.

This means of stubbing an external service is not possible when using the "in-memory" testing application (which is the default behavior for `VaporTesting`).
Attempting to do so will result in "connection refused" when attempting to make requests to these external service via an `HTTPClient`.
It is possible to stub this way when using a TCP connection (e.g. a `localhost` server).

However, there is a more efficient way to achieve this type of stubbing with UNIX domain sockets.
UDS allow for inter-process communication to occur on the same operating system.
Communicating over UDS is more efficient than communicating over TCP.

### How do I use this SDK?

This SDK was designed to work alongside the `VaporTesting` library.

Let's say we have server that sends alerts to some endpoint whenever it receives a message.
For simplicity, I will only show the `RouteCollection` for the application.
Otherwise, assume it's a normative Vapor application.

```swift
import Vapor

struct MessageRouteController: RouteCollection {
    let alertBaseURL: URL

    func boot(routes: any RoutesBuilder) throws {
        routes.post("message", use: { req async throws in
            let message = req.body.string ?? ""
            do {
                let alertEndpoint = alertBaseURL.appending(path: "alert").absoluteString
                let res = try await req.client.post(URI(string: alertEndpoint), content: message)
                return res.status
            } catch {
                return HTTPResponseStatus.internalServerError
            }
        })
    }
}
```

In our tests, we will define a stub `RouteCollection` for the external alerting service.
The stub service will return either `200` or `400`, depending on the content of the message.
```swift
import Vapor

struct StubAlertRouteController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.post("alert", use: { req async throws in
            let message = req.body.string ?? ""
            switch message {
            case "stub_ok": return HTTPResponseStatus.ok
            default: return HTTPResponseStatus.badRequest
            }
        })
    }
}
```

We'll then perform the following steps in our test functions:
1. Create a testing application using `VaporTesting.withApp`.
2. Create a `TemporarySocket` using `withTemporarySocket` to use during testing (this is the UDS we'll be communicating over).
3. Setup the routes, making use to use the socket URL for the stubbed service route.
4. Finally, test the application using the `testing` API to specify UDS.

```swift
import Testing
import Vapor
import VaporTesting
import VaporTestingSocketServer

@Test
func messageReturnsOkOnSuccessfulAlert() async throws {
    // (1)
    try await VaporTesting.withApp { app in
        // (2)
        try await withTemporarySocket { tempSocket in 
            // (3)
            try app.register(collection: MessageRouteController(alertBaseURL: tempSocket.url))
            try app.register(collection: StubAlertRouteController())

            // (4)
            try await app.testing(method: .unixDomainSocket(path: tempSocket.path))
                .test(.GET, "message", beforeResponse: { res async throws in 
                    try req.body.writeString("stub_ok", encoding: .utf8)
                }, afterResponse: { res async throws in
                    #expect(res.status == .ok)
                })
        }
    }
}
```

## Topics

### Create Socket

- ``withTemporarySocket(function:_:)-52exl``
- ``withTemporarySocket(function:_:)-43u4g``
- ``TemporarySocket``
- ``TemporarySocketError``

### Test Application

- ``Vapor/Application/testing(method:)``
- ``Vapor/Application/SocketServerMethod``
