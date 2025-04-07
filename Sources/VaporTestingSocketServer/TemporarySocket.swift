//
//  TemporarySocket.swift
//  VaporTestingSocketServer
//
//  Created by Annalise Mariottini on 4/6/25.
//

import AsyncHTTPClient
import Foundation
import NIOCore

/// Creates a temporary UNIX domain socket for usage within the passed closure's scope.
///
/// - Parameter action: The closure to execute with the temporary UNIX domain socket.
///
/// - Warning: When the socket is created, the current working directory may change, since UDS paths may not be too long.
/// The passed socket retains the previous current working directory in the variable ``TemporarySocket/savedCurrentWorkingDirectory``,
/// which may be restored by calling ``TemporarySocket/restoreSavedCurrentWorkingDirectory()``.
/// This function will automatically be called when the closure completes.
/// **If you choose to restore the saved working directory within the closure, you should only do so after application testing is complete.**
@discardableResult
public func withTemporarySocket<O>(function: String = #function, _ action: (inout TemporarySocket) async throws -> O) async throws -> O {
    var socket = try TemporarySocket(function: function)
    let output = try await action(&socket)
    socket.restoreSavedCurrentWorkingDirectory()
    return output
}

/// Creates a temporary UNIX domain socket for usage within the passed closure's scope.
///
/// - Parameter action: The closure to execute with the temporary UNIX domain socket.
///
/// - Warning: When the socket is created, the current working directory may change, since UDS paths may not be too long.
/// The passed socket retains the previous current working directory in the variable ``TemporarySocket/savedCurrentWorkingDirectory``,
/// which may be restored by calling ``TemporarySocket/restoreSavedCurrentWorkingDirectory()``.
/// This function will automatically be called when the closure completes.
/// **If you choose to restore the saved working directory within the closure, you should only do so after application testing is complete.**
@discardableResult
public func withTemporarySocket<O>(function: String = #function, _ action: (inout TemporarySocket) throws -> O) throws -> O {
    var socket = try TemporarySocket(function: function)
    let output = try action(&socket)
    socket.restoreSavedCurrentWorkingDirectory()
    return output
}

/// A representation of a temporary UNIX domain socket for testing purposes.
public struct TemporarySocket {
    init(function: String) throws {
        let (path, url, savedCurrentWorkingDirectory) = try Self.makeTemporarySocketFile(function: function)
        self.init(path: path, url: url, savedCurrentWorkingDirectory: savedCurrentWorkingDirectory)
    }

    private init(path: String, url: URL, savedCurrentWorkingDirectory: String?) {
        self.path = path
        self.url = url
        self.savedCurrentWorkingDirectory = savedCurrentWorkingDirectory
    }

    /// The path to the socket in the file system (relative to the current working directory).
    public let path: String
    /// The HTTP url to use to connect to this socket.
    public let url: URL
    /// If the working directory had to be changed to accomodate the socket file path, this is the saved previous working directory.
    /// This directory may be restored by calling ``restoreSavedCurrentWorkingDirectory()``.
    public private(set) var savedCurrentWorkingDirectory: String?

    /// If it was necessary to change working directories to use a shorter UNIX domain socket path, this function will change the directory back to the previously saved working directory.
    ///
    /// - Note: This is called at the end of ``withTemporarySocket(function:_:)-52exl`` and ``withTemporarySocket(function:_:)-43u4g``.
    public mutating func restoreSavedCurrentWorkingDirectory() {
        if let savedCurrentWorkingDirectory {
            if FileManager.default.changeCurrentDirectoryPath(savedCurrentWorkingDirectory) {
                self.savedCurrentWorkingDirectory = nil
            }
        }
    }

    static func makeTemporarySocketFile(function: String) throws -> (path: String, url: URL, savedCurrentWorkingDirectory: String?) {
        let fileSafeFunctionName = function.fileSafeName
        var temporaryDirectory = NSTemporaryDirectory()
        if temporaryDirectory.last != "/" {
            temporaryDirectory += "/"
        }
        let path = "\(temporaryDirectory)\(fileSafeFunctionName).sock"
        // make sure that there's no leftover socket (binding will fail later otherwise)
        if FileManager.default.fileExists(atPath: path) {
            try FileManager.default.removeItem(atPath: path)
        }

        do {
            // make sure the socket path is short enough
            _ = try SocketAddress(unixDomainSocketPath: path)
            guard let url = URL(httpURLWithSocketPath: path) else {
                throw TemporarySocketError.unableToCreateSocketURL
            }
            return (path, url, nil)
        } catch SocketAddressError.unixDomainSocketPathTooLong {
            // the socket path is too long
            let savedCurrentWorkingDirectory = FileManager.default.currentDirectoryPath
            let socketDirectory = URL(fileURLWithPath: path).deletingLastPathComponent().absoluteURL.path
            let shorterPath = URL(fileURLWithPath: path).lastPathComponent
            guard let url = URL(httpURLWithSocketPath: shorterPath) else {
                throw TemporarySocketError.unableToCreateSocketURL
            }
            print("""
            WARNING:
            - Path '\(path)' could not be used as UNIX domain socket path, using chdir & '\(shorterPath)'
            - Socket directory: \(socketDirectory)
            - Saved working directory: \(savedCurrentWorkingDirectory)
            """)
            if FileManager.default.changeCurrentDirectoryPath(socketDirectory) == false {
                throw TemporarySocketError.unableToChangeWorkingDirectory
            }
            return (shorterPath, url, savedCurrentWorkingDirectory)
        }
    }
}

private extension String {
    var fileSafeName: String {
        replacingOccurrences(of: "[^a-zA-Z_-]", with: "", options: .regularExpression)
    }
}

/// Errors that may be thrown when attempting to create a ``TemporarySocket``.
public enum TemporarySocketError: Error {
    /// The socket URL initialization returned `nil`.
    case unableToCreateSocketURL
    /// Failed changing working directories.
    case unableToChangeWorkingDirectory
}
