import Foundation

struct BenchmarkScoreCalculator {
    nonisolated static func scores(
        speed: BenchmarkSpeedMetrics?,
        agent: BenchmarkAgentReadiness?
    ) -> [BenchmarkUseCaseScore] {
        [
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
                reasonCodes: [incompleteSpeedReason(speed)]
            )
        }

        var score = 10
        var reasons: [BenchmarkScoreReasonCode] = []

        if let ttftMS = speed.ttftMS {
            if ttftMS > 10_000 {
                score -= 3
                reasons.append(.ttftSlowInteractive)
            } else if ttftMS > 5_000 {
                score -= 2
                reasons.append(.ttftDelayed)
            } else if ttftMS > 2_500 {
                score -= 1
                reasons.append(.ttftAcceptable)
            } else {
                reasons.append(.ttftResponsive)
            }
        } else {
            score -= 2
            reasons.append(.ttftUnavailable)
        }

        if let tokensPerSecond = speed.outputTokensPerSecond {
            if tokensPerSecond < 4 {
                score -= 4
                reasons.append(.chatGenerationTooSlow)
            } else if tokensPerSecond < 8 {
                score -= 3
                reasons.append(.generationLimited)
            } else if tokensPerSecond < 15 {
                score -= 2
                reasons.append(.generationUsable)
            } else if tokensPerSecond < 25 {
                score -= 1
                reasons.append(.generationPractical)
            } else {
                reasons.append(.generationStrong)
            }
        } else {
            score -= 2
            reasons.append(.generationUnavailable)
        }

        if speed.finishReason == "length" {
            score -= 1
            reasons.append(.responseTokenLimit)
        }

        applyMemoryPenalty(speed: speed, score: &score, reasons: &reasons)

        return BenchmarkUseCaseScore(
            useCase: .chat,
            score: clamp(score),
            reasonCodes: trimmedReasons(reasons)
        )
    }

    nonisolated private static func codingScore(
        speed: BenchmarkSpeedMetrics?,
        agent: BenchmarkAgentReadiness?
    ) -> BenchmarkUseCaseScore {
        guard let speed, speed.errorMessage == nil, !speed.timedOut else {
            return BenchmarkUseCaseScore(
                useCase: .coding,
                score: 1,
                reasonCodes: [incompleteSpeedReason(speed)]
            )
        }

        var score = 10
        var reasons: [BenchmarkScoreReasonCode] = []

        if let tokensPerSecond = speed.outputTokensPerSecond {
            if tokensPerSecond < 4 {
                score -= 4
                reasons.append(.codeLongResponsesSlow)
            } else if tokensPerSecond < 8 {
                score -= 3
                reasons.append(.codeGenerationLimited)
            } else if tokensPerSecond < 14 {
                score -= 2
                reasons.append(.codeGenerationUsable)
            } else {
                reasons.append(.codeGenerationPractical)
            }
        } else {
            score -= 2
            reasons.append(.generationUnavailable)
        }

        if speed.finishReason == "length" {
            score -= 2
            reasons.append(.generationTokenLimit)
        }

        if let agent {
            let instructionRate = ratio(agent.instructionFollowingPasses, agent.totalRuns)
            if instructionRate < 0.6 {
                score -= 3
                reasons.append(.instructionProbesUnstable)
            } else if instructionRate < 0.85 {
                score -= 1
                reasons.append(.instructionProbesMostlyUsable)
            } else {
                reasons.append(.instructionProbesStable)
            }
        }

        applyMemoryPenalty(speed: speed, score: &score, reasons: &reasons)

        return BenchmarkUseCaseScore(
            useCase: .coding,
            score: clamp(score),
            reasonCodes: trimmedReasons(reasons)
        )
    }

    nonisolated private static func agentScore(
        speed: BenchmarkSpeedMetrics?,
        agent: BenchmarkAgentReadiness?
    ) -> BenchmarkUseCaseScore {
        guard let speed, speed.errorMessage == nil, !speed.timedOut else {
            return BenchmarkUseCaseScore(
                useCase: .agent,
                score: 1,
                reasonCodes: [incompleteSpeedReason(speed)]
            )
        }

        guard let agent, agent.totalRuns > 0 else {
            return BenchmarkUseCaseScore(
                useCase: .agent,
                score: 3,
                reasonCodes: [.agentProbesUnavailable]
            )
        }

        var score = 10
        var reasons: [BenchmarkScoreReasonCode] = []

        let jsonRate = ratio(agent.jsonValidResponses, agent.totalRuns)
        if jsonRate < 0.5 {
            score -= 5
            reasons.append(.jsonUnreliable)
        } else if jsonRate < 0.8 {
            score -= 3
            reasons.append(.jsonSometimesBreaks)
        } else if jsonRate < 1.0 {
            score -= 1
            reasons.append(.jsonMostlyStable)
        } else {
            reasons.append(.jsonStable)
        }

        let instructionRate = ratio(agent.instructionFollowingPasses, agent.totalRuns)
        if instructionRate < 0.6 {
            score -= 3
            reasons.append(.agentInstructionWeak)
        } else if instructionRate < 0.85 {
            score -= 2
            reasons.append(.agentInstructionCaution)
        } else {
            reasons.append(.agentInstructionPractical)
        }

        let expectedToolProbeCount = max(agent.toolSelectionProbeCount, 1)
        let toolRate = ratio(agent.toolSelectionPasses, expectedToolProbeCount)
        if toolRate < 0.6 {
            score -= 3
            reasons.append(.toolSelectionUnreliable)
        } else if toolRate < 0.85 {
            score -= 1
            reasons.append(.toolSelectionMostlyUsable)
        } else {
            reasons.append(.toolSelectionStable)
        }

        if agent.timeoutCount > 0 {
            score -= min(agent.timeoutCount * 2, 4)
            reasons.append(.probeTimeouts)
        }

        if agent.lengthFinishCount > 0 {
            score -= min(agent.lengthFinishCount, 3)
            reasons.append(.probeTokenLength)
        }

        if let ttftMS = agent.averageTTFTMS ?? speed.ttftMS {
            if ttftMS > 6_000 {
                score -= 2
                reasons.append(.repeatedLatencyHigh)
            } else if ttftMS > 3_000 {
                score -= 1
                reasons.append(.repeatedLatencyAcceptable)
            }
        }

        applyMemoryPenalty(speed: speed, score: &score, reasons: &reasons)

        return BenchmarkUseCaseScore(
            useCase: .agent,
            score: clamp(score),
            reasonCodes: trimmedReasons(reasons)
        )
    }

    nonisolated private static func applyMemoryPenalty(
        speed: BenchmarkSpeedMetrics,
        score: inout Int,
        reasons: inout [BenchmarkScoreReasonCode]
    ) {
        guard let available = speed.availableMemoryGigabytes else {
            return
        }
        if available < 4 {
            score -= 2
            reasons.append(.memoryTight)
        } else if available < 8 {
            score -= 1
            reasons.append(.memoryLimited)
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

    nonisolated private static func trimmedReasons(
        _ reasons: [BenchmarkScoreReasonCode]
    ) -> [BenchmarkScoreReasonCode] {
        Array(reasons.prefix(3))
    }

    nonisolated private static func incompleteSpeedReason(
        _ speed: BenchmarkSpeedMetrics?
    ) -> BenchmarkScoreReasonCode {
        guard let speed else {
            return .speedNotRun
        }
        if speed.timedOut {
            return .speedTimedOut
        }

        let message = speed.errorMessage?.lowercased() ?? ""
        if message.contains("reasoning") && message.contains("token limit") {
            return .reasoningTokenBudget
        }
        if message.contains("reasoning") {
            return .reasoningOnly
        }
        if message.contains("token limit") {
            return .contentTokenLimit
        }
        if message.contains("empty response") {
            return .emptyBenchmarkContent
        }
        return .speedIncomplete
    }
}
