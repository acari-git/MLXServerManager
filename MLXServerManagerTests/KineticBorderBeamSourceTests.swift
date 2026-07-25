import Foundation
import XCTest
@testable import MLXServerManager

final class KineticBorderBeamSourceTests: XCTestCase {
    func testBorderBeamLetsTheSystemChooseTheRefreshInterval() {
        XCTAssertNil(
            KineticBorderBeamAnimationPolicy.minimumInterval,
            "Border Beam must let SwiftUI and the display choose the animation refresh interval."
        )
    }

    func testBorderBeamAnimationPolicyPausesForEveryInactiveCondition() {
        XCTAssertFalse(
            KineticBorderBeamAnimationPolicy.shouldPause(
                reduceMotion: false,
                isVisible: true,
                isSceneActive: true
            )
        )
        XCTAssertTrue(
            KineticBorderBeamAnimationPolicy.shouldPause(
                reduceMotion: true,
                isVisible: true,
                isSceneActive: true
            )
        )
        XCTAssertTrue(
            KineticBorderBeamAnimationPolicy.shouldPause(
                reduceMotion: false,
                isVisible: false,
                isSceneActive: true
            )
        )
        XCTAssertTrue(
            KineticBorderBeamAnimationPolicy.shouldPause(
                reduceMotion: false,
                isVisible: true,
                isSceneActive: false
            )
        )
    }

    func testBorderBeamProgressUsesDurationAndFreezesForReducedMotion() {
        let date = Date(timeIntervalSinceReferenceDate: 1.25)

        XCTAssertEqual(
            KineticBorderBeamAnimationPolicy.progress(
                at: date,
                duration: 2,
                reduceMotion: false
            ),
            0.625,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            KineticBorderBeamAnimationPolicy.progress(
                at: date,
                duration: 2,
                reduceMotion: true
            ),
            KineticBorderBeamAnimationPolicy.reducedMotionProgress
        )
        XCTAssertEqual(
            KineticBorderBeamAnimationPolicy.progress(
                at: date,
                duration: 0,
                reduceMotion: false
            ),
            KineticBorderBeamAnimationPolicy.reducedMotionProgress
        )
    }

    func testBorderBeamRetainsDecorativeAccessibilityGuards() throws {
        let source = try Self.source(at: "MLXServerManager/Views/KineticControls.swift")
        let requiredSnippets = [
            "@Environment(\\.accessibilityReduceMotion)",
            "@Environment(\\.accessibilityReduceTransparency)",
            "@Environment(\\.scenePhase)",
            ".allowsHitTesting(false)",
            ".accessibilityHidden(true)"
        ]
        let missing = requiredSnippets.filter { !source.contains($0) }

        XCTAssertTrue(
            missing.isEmpty,
            "Border Beam must remain decorative and accessibility-aware: \(missing)"
        )
    }

    func testBorderBeamUsageRemainsBoundToExplicitOperationalState() throws {
        let workspace = try Self.source(at: "MLXServerManager/Views/IntegratedWorkspaceView.swift")
        let downloads = try Self.source(at: "MLXServerManager/Views/DownloadsSurfaceView.swift")
        let requiredWorkspaceBindings = [
            "isActive: row.isTransitioning",
            "isActive: viewModel.isModelTransitioning(model)",
            "isActive: viewModel.isMiniChatRunning"
        ]
        let missingWorkspaceBindings = requiredWorkspaceBindings.filter { !workspace.contains($0) }

        XCTAssertTrue(
            missingWorkspaceBindings.isEmpty,
            "Workspace Border Beams must remain tied to explicit transition or request state: \(missingWorkspaceBindings)"
        )
        XCTAssertTrue(
            downloads.contains("isActive: isTransferActive"),
            "Download Border Beam must remain tied to the derived active-transfer state."
        )
        XCTAssertTrue(
            downloads.contains("case .preparing, .downloading, .finalizing:"),
            "Only active download phases should animate the transfer card."
        )
    }

    private static func source(at relativePath: String) throws -> String {
        let root = try projectRoot()
        return try String(
            contentsOf: root.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    private static func projectRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while directory.path != "/" {
            if FileManager.default.fileExists(
                atPath: directory.appendingPathComponent("MLXServerManager.xcodeproj").path
            ) {
                return directory
            }
            directory.deleteLastPathComponent()
        }
        throw NSError(domain: "KineticBorderBeamSourceTests", code: 1)
    }
}
