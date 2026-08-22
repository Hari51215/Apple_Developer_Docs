//
// PlacementController.swift
// ARDrop
//
// Owns the ARSCNView's delegate callbacks: visualizing detected planes,
// hit-testing taps against them, and placing/clearing cube nodes.
//

import ARKit
import Combine
import SceneKit
import UIKit

final class PlacementController: NSObject, ObservableObject, ARSCNViewDelegate, ARSessionDelegate {

    @Published var statusMessage = "Move your device slowly to find a flat surface"
    @Published var placedCount = 0

    weak var sceneView: ARSCNView?

    private var placedNodes: [SCNNode] = []
    private var planeNodes: [UUID: SCNNode] = [:]

    // MARK: - ARSessionDelegate (session-level failures, not forwarded by ARSCNViewDelegate)

    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.statusMessage = "AR session failed: \(error.localizedDescription)"
        }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        DispatchQueue.main.async { [weak self] in
            self?.statusMessage = "Session interrupted — check camera access in Settings"
        }
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        reset()
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        guard case .limited(let reason) = camera.trackingState else { return }
        let explanation: String
        switch reason {
        case .initializing: explanation = "Initializing — hold steady"
        case .excessiveMotion: explanation = "Too much motion — slow down"
        case .insufficientFeatures: explanation = "Not enough detail here — try a more textured surface or better light"
        case .relocalizing: explanation = "Relocalizing"
        @unknown default: explanation = "Limited tracking"
        }
        DispatchQueue.main.async { [weak self] in
            self?.statusMessage = explanation
        }
    }

    // MARK: - ARSCNViewDelegate

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        let planeNode = makePlaneNode(for: planeAnchor)
        node.addChildNode(planeNode)
        planeNodes[planeAnchor.identifier] = planeNode

        DispatchQueue.main.async { [weak self] in
            self?.statusMessage = "Surface found — tap it to drop a cube"
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor,
              let planeNode = planeNodes[planeAnchor.identifier],
              let plane = planeNode.geometry as? SCNPlane else { return }

        plane.width = CGFloat(planeAnchor.extent.x)
        plane.height = CGFloat(planeAnchor.extent.z)
        planeNode.position = SCNVector3(planeAnchor.center.x, 0, planeAnchor.center.z)
    }

    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        planeNodes.removeValue(forKey: planeAnchor.identifier)
    }

    // MARK: - Tap to place

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let sceneView else { return }
        let location = gesture.location(in: sceneView)

        guard let query = sceneView.raycastQuery(
            from: location,
            allowing: .existingPlaneGeometry,
            alignment: .horizontal
        ) else { return }

        guard let result = sceneView.session.raycast(query).first else { return }

        let cube = makeCubeNode()
        cube.simdTransform = result.worldTransform
        cube.position.y += 0.03
        sceneView.scene.rootNode.addChildNode(cube)

        placedNodes.append(cube)
        placedCount += 1
    }

    // MARK: - Reset

    func reset() {
        placedNodes.forEach { $0.removeFromParentNode() }
        placedNodes.removeAll()
        placedCount = 0

        planeNodes.values.forEach { $0.removeFromParentNode() }
        planeNodes.removeAll()

        statusMessage = "Move your device slowly to find a flat surface"

        guard let sceneView else { return }
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    // MARK: - Node factories

    private func makePlaneNode(for anchor: ARPlaneAnchor) -> SCNNode {
        let plane = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        plane.firstMaterial?.diffuse.contents = UIColor.systemBlue.withAlphaComponent(0.25)
        plane.firstMaterial?.isDoubleSided = true

        let node = SCNNode(geometry: plane)
        node.eulerAngles.x = -.pi / 2
        node.position = SCNVector3(anchor.center.x, 0, anchor.center.z)
        return node
    }

    private func makeCubeNode() -> SCNNode {
        let box = SCNBox(width: 0.06, height: 0.06, length: 0.06, chamferRadius: 0.004)
        box.firstMaterial?.diffuse.contents = UIColor.systemOrange
        return SCNNode(geometry: box)
    }
}
