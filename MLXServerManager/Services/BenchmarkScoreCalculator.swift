import Foundation

struct BenchmarkScoreCalculator {
    nonisolated static func scores(
        speed: BenchmarkSpeedMetrics?,
        agent: BenchmarkAgentReadiness?
    ) -> [BenchmarkUseCaseScore] {
        return [
            chatScore(speed: speed),
            codingScore(speed: speed, agent: agent),
            agentScore(speed: speed, agent: agent)
        ]
    }

    nonisolated private static func chatScore(speed: BenchmarkSpeedMetrics?) -> BenchmarkUseCaseScore {
        guard let speed, speed.errorMessage == nil, !speed.timedOut else {
            return BenchmarkUseCaseScore(
                useCase: .chat,
                score: 1,
                reasons: [incompleteSpeedReason(speed)]
            )
        }

        var score = 10
        var reasons: [String] = []

        if let ttftMS = speed.ttftMS {
            if ttftMS > 10_000 {
                score -= 3
                reasons.append("TTFT is slow for interactive chat.")
            } else if ttftMS > 5_000 {
                score -= 2
                reasons.append("TTFT may feel delayed.")
            } else if ttftMS > 2_500 {
                score -= 1
                reasons.append("TTFT is acceptable but not instant.")
            } else {
                reasons.append("TTFT is responsive.")
            }
        } else {
            score -= 2
            reasons.append("TTFT could not be measured.")
        }

        if let tokensPerSecond = speed.outputTokensPerSecond {
            if tokensPerSecond < 4 {
                score -= 4
                reasons.append("Generation speed is too slow for comfortable chat.")
            } else if tokensPerSecond < 8 {
                score -= 3
                reasons.append("Generation speed is limited.")
            } else if tokensPerSecond < 15 {
                score -= 2
                reasons.append("Generation speed is usable.")
            } else if tokensPerSecond < 25 {
                score -= 1
                reasons.append("Generation speed is practical.")
            } else {
                reasons.append("Generation speed is strong.")
            }
        } else {
            score -= 2
            reasons.append("Generation speed could not be measured.")
        }

        if speed.finishReason == "length" {
            score -= 1
            reasons.append("The response hit the token limit.")
        }

        applyMemoryPenalty(speed: speed, score: &score, reasons: &reasons)

        return BenchmarkUseCaseScore(useCase: .chat, score: clamp(score), reasons: trimmedReasons(reasons))
    }

    nonisolated private static func codingScore(
        speed: BenchmarkSpeedMetrics?,
        agent: BenchmarkAgentReadiness?
    ) -> BenchmarkUseCaseScore {
        guard let speed, speed.errorMessage == nil, !speed.timedOut else {
            return BenchmarkUseCaseScore(
                useCase: .coding,
                score: 1,
                reasons: [incompleteSpeedReason(speed)]
            )
        }

        var score = 10
        var reasons: [String] = []

        if let tokensPerSecond = speed.outputTokensPerSecond {
            if tokensPerSecond < 4 {
                score -= 4
                reasons.append("Long code responses will be very slow.")
            } else if tokensPerSecond < 8 {
                score -= 3
                reasons.append("Code generation speed is limited.")
            } else if tokensPerSecond < 14 {
                score -= 2
                reasons.append("Code generation speed is usable.")
            } else {
                reasons.append("Code generation speed is practical.")
            }
        } else {
            score -= 2
            reasons.append("Generation speed could not be measured.")
        }

        if speed.finishReason == "length" {
            score -= 2
            reasons.append("The model hit the token limit during generation.")
        }

        if let agent {
            let instructionRate = ratio(agent.instructionFollowingPasses, agent.totalRuns)
            if instructionRate < 0.6 {
                score -= 3
                reasons.append("Instruction-following probes were unstable.")
            } else if instructionRate < 0.85 {
                score -= 1
                reasons.append("Instruction-following probes were mostly usable.")
            } else {
                reasons.append("Instruction-following probes were stable.")
            }
        }

        applyMemoryPenalty(speed: speed, score: &score, reasons: &reasons)

        return BenchmarkUseCaseScore(useCase: .coding, score: clamp(score), reasons: trimmedReasons(reasons))
    }

    nonisolated private static func agentScore(
        speed: BenchmarkSpeedMetrics?,
        agent: BenchmarkAgentReadiness?
    ) -> BenchmarkUseCaseScore {
        guard let speed, speed.errorMessage == nil, !speed.timedOut else {
            return BenchmarkUseCaseScore(
                useCase: .agent,
                score: 1,
                reasons: [incompleteSpeedReason(speed)]
            )
        }

        guard let agent, agent.totalRuns > 0 else {
            return BenchmarkUseCaseScore(
                useCase: .agent,
                score: 3,
                reasons: ["Agent readiness probes were not available."]
            )
        }

        var score = 10
        var reasons: [String] = []

        let jsonRate = ratio(agent.jsonValidResponses, agent.totalRuns)
        if jsonRate < 0.5 {
            score -= 5
            reasons.append("JSON output is unreliable.")
        } else if jsonRate < 0.8 {
            score -= 3
            reasons.append("JSON output sometimes breaks.")
        } else if jsonRate < 1.0 {
            score -= 1
            reasons.append("JSON output is mostly stable.")
        } else {
            reasons.append("JSON output was stable.")
        }

        let instructionRate = ratio(agent.instructionFollowingPasses, agent.totalRuns)
        if instructionRate < 0.6 {
            score -= 3
            reasons.append("Instruction following is weak for agent loops.")
        } else if instructionRate < 0.85 {
            score -= 2
            reasons.append("Instruction following needs caution.")
        } else {
            reasons.append("Instruction following is practical.")
        }

        let expectedToolProbeCount = max(agent.totalRuns - 2, 1)
        let toolRate = ratio(agent.toolSelectionPasses, expectedToolProbeCount)
        if toolRate < 0.6 {
            score -= 3
            reasons.append("Tool-selection probes were unreliable.")
        } else if toolRate < 0.85 {
            score -= 1
            reasons.append("Tool-selection probes were mostly usable.")
        } else {
            reasons.append("Tool-selection probes were stable.")
        }

        if agent.timeoutCount > 0 {
            score -= min(agent.timeoutCount * 2, 4)
            reasons.append("Timeouts occurred during repeated probes.")
        }

        if agent.lengthFinishCount > 0 {
            score -= min(agent.lengthFinishCount, 3)
            reasons.append("Some probes stopped because of token length.")
        }

        if let ttftMS = agent.averageTTFTMS ?? speed.ttftMS {
            if ttftMS > 6_000 {
                score -= 2
                reasons.append("Repeated short-task latency is high.")
            } else if ttftMS > 3_000 {
                score -= 1
                reasons.append("Repeated short-task latency is acceptable.")
            }
        }

        applyMemoryPenalty(speed: speed, score: &score, reasons: &reasons)

        return BenchmarkUseCaseScore(useCase: .agent, score: clamp(score), reasons: trimmedReasons(reasons))
    }

    nonisolated private static func applyMemoryPenalty(
        speed: BenchmarkSpeedMetrics,
        score: inout Int,
        reasons: inout [String]
    ) {
        guard let available = speed.availableMemoryGigabytes else {
            return
        }
        if available < 4 {
            score -= 2
            reasons.append("Memory headroom is tight on this Mac.")
        } else if available < 8 {
            score -= 1
            reasons.append("Memory headroom is limited.")
        }
    }

    nonisolated private static func ratio(_ numerator: Int, _ denominator: Int) -> Double {
        guard denominator > 0 else {
            return 0
        }
        return Double(numerator) / Double(denominator)
    }

    nonisolated private static func clamp(_ score: Int) -> Int {
        min(max(score, 1), 10)
    }

    nonisolated private static func trimmedReasons(_ reasons: [String]) -> [String] {
        Array(reasons.prefix(3))
    }

    nonisolated private static func incompleteSpeedReason(_ speed: BenchmarkSpeedMetrics?) -> String {
        guard let speed else {
            return "Speed test did not run."
        }
        if speed.timedOut {
            return "Endpoint timed out during the speed test."
        }

        let message = speed.errorMessage?.lowercased() ?? ""
        if message.contains("reasoning") && message.contains("token limit") {
            return "Model used the token budget on reasoning before final content."
        }
        if message.contains("reasoning") {
            return "Model returned reasoning without final content."
        }
        if message.contains("token limit") {
            return "Response reached the token limit before content."
        }
        if message.contains("empty response") {
            return "Endpoint returned no benchmark content."
        }
        return "Endpoint did not complete the speed test."
    }
}
