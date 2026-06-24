import Darwin
import Foundation

struct CPUUsageSampler: Sendable {
    private var previousSample: host_cpu_load_info?

    nonisolated init() {}

    nonisolated mutating func samplePercent() -> Double? {
        guard let currentSample = Self.currentCPULoadInfo() else {
            return nil
        }
        defer {
            previousSample = currentSample
        }

        guard let previousSample else {
            return nil
        }

        let previousTicks = Self.ticks(from: previousSample)
        let currentTicks = Self.ticks(from: currentSample)
        let user = Double(currentTicks.user - previousTicks.user)
        let system = Double(currentTicks.system - previousTicks.system)
        let idle = Double(currentTicks.idle - previousTicks.idle)
        let nice = Double(currentTicks.nice - previousTicks.nice)
        let total = user + system + idle + nice
        guard total > 0 else { return nil }
        return min(max(((total - idle) / total) * 100, 0), 100)
    }

    nonisolated private static func currentCPULoadInfo() -> host_cpu_load_info? {
        var loadInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &loadInfo) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, reboundPointer, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return loadInfo
    }

    nonisolated private static func ticks(from info: host_cpu_load_info) -> (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32) {
        (
            user: info.cpu_ticks.0,
            system: info.cpu_ticks.1,
            idle: info.cpu_ticks.2,
            nice: info.cpu_ticks.3
        )
    }
}
