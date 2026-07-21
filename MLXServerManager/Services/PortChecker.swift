import Darwin
import Foundation

nonisolated enum PortCheckResult: Equatable {
    case available(host: String, port: Int)
    case busy(host: String, port: Int, pid: Int?)
    case invalidInput(message: String)
    case failed(host: String, port: Int, message: String)
}

nonisolated struct PortChecker {
    func check(host: String, port: Int) -> PortCheckResult {
        guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .invalidInput(message: "Host is empty.")
        }

        guard (1...65535).contains(port) else {
            return .invalidInput(message: "Port must be between 1 and 65535.")
        }

        guard var address = socketAddress(host: host, port: UInt16(port)) else {
            return .invalidInput(message: "Only IPv4 host values such as 127.0.0.1 are supported in v0.1.")
        }

        let socketDescriptor = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard socketDescriptor >= 0 else {
            let errorCode = errno
            return .failed(
                host: host,
                port: port,
                message: errorMessage(prefix: "socket failed", errorCode: errorCode)
            )
        }

        defer {
            close(socketDescriptor)
        }

        var reuseAddress: Int32 = 1
        let socketOptionResult = withUnsafePointer(to: &reuseAddress) { pointer in
            setsockopt(
                socketDescriptor,
                SOL_SOCKET,
                SO_REUSEADDR,
                pointer,
                socklen_t(MemoryLayout<Int32>.size)
            )
        }
        guard socketOptionResult == 0 else {
            return resultForSocketOptionFailure(host: host, port: port, errorCode: errno)
        }

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketPointer in
                Darwin.bind(
                    socketDescriptor,
                    socketPointer,
                    socklen_t(MemoryLayout<sockaddr_in>.size)
                )
            }
        }

        guard bindResult == 0 else {
            return resultForBindFailure(host: host, port: port, errorCode: errno)
        }

        guard listen(socketDescriptor, 1) == 0 else {
            return .failed(
                host: host,
                port: port,
                message: errorMessage(prefix: "listen failed", errorCode: errno)
            )
        }

        return .available(host: host, port: port)
    }

    private func socketAddress(host: String, port: UInt16) -> sockaddr_in? {
        let normalizedHost = host == "localhost" ? "127.0.0.1" : host
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian

        let conversionResult = normalizedHost.withCString { hostPointer in
            inet_pton(AF_INET, hostPointer, &address.sin_addr)
        }

        guard conversionResult == 1 else {
            return nil
        }

        return address
    }


    func resultForSocketOptionFailure(host: String, port: Int, errorCode: Int32) -> PortCheckResult {
        .failed(
            host: host,
            port: port,
            message: errorMessage(prefix: "setsockopt SO_REUSEADDR failed", errorCode: errorCode)
        )
    }

    func resultForBindFailure(host: String, port: Int, errorCode: Int32) -> PortCheckResult {
        if errorCode == EADDRINUSE {
            return .busy(host: host, port: port, pid: nil)
        }
        return .failed(
            host: host,
            port: port,
            message: errorMessage(prefix: "bind failed", errorCode: errorCode)
        )
    }

    private func errorMessage(prefix: String, errorCode: Int32) -> String {
        "\(prefix): \(String(cString: strerror(errorCode)))"
    }
}
