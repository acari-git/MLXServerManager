import Darwin
import Foundation

enum PortCheckResult: Equatable {
    case available(host: String, port: Int)
    case busy(host: String, port: Int)
    case invalidInput(message: String)
    case failed(host: String, port: Int, message: String)
}

struct PortChecker {
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
            return .failed(host: host, port: port, message: errorMessage(prefix: "socket failed"))
        }

        defer {
            close(socketDescriptor)
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
            if errno == EADDRINUSE {
                return .busy(host: host, port: port)
            }

            return .failed(host: host, port: port, message: errorMessage(prefix: "bind failed"))
        }

        guard listen(socketDescriptor, 1) == 0 else {
            return .failed(host: host, port: port, message: errorMessage(prefix: "listen failed"))
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

    private func errorMessage(prefix: String) -> String {
        "\(prefix): \(String(cString: strerror(errno)))"
    }
}

