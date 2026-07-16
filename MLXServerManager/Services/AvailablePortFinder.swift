import Foundation

nonisolated struct AvailablePortFinder {
    private let checkPort: (String, Int) -> PortCheckResult

    init(checkPort: @escaping (String, Int) -> PortCheckResult = { host, port in
        PortChecker().check(host: host, port: port)
    }) {
        self.checkPort = checkPort
    }

    func firstAvailablePort(
        host: String,
        preferredPort: Int,
        reservedPorts: Set<Int>,
        searchLimit: Int = 100
    ) -> Int? {
        guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              (1...65_535).contains(preferredPort),
              searchLimit > 0 else {
            return nil
        }

        let remainingPortCount = 65_535 - preferredPort
        let searchOffset = min(searchLimit - 1, remainingPortCount)
        let upperBound = preferredPort + searchOffset
        for port in preferredPort...upperBound where !reservedPorts.contains(port) {
            switch checkPort(host, port) {
            case .available:
                return port
            case .invalidInput:
                return nil
            case .busy, .failed:
                continue
            }
        }
        return nil
    }
}
