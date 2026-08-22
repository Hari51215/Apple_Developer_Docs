//
// ARViewContainer.swift
// ARDrop
//
// Bridges ARSCNView into SwiftUI and starts the AR session.
//

import ARKit
import SwiftUI

struct ARViewContainer: UIViewRepresentable {
    let controller: PlacementController

    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView(frame: .zero)
        sceneView.scene = SCNScene()
        sceneView.delegate = controller
        sceneView.session.delegate = controller
        sceneView.autoenablesDefaultLighting = true
        controller.sceneView = sceneView

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        sceneView.session.run(configuration)

        let tapGesture = UITapGestureRecognizer(target: controller, action: #selector(PlacementController.handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)

        return sceneView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Nothing to update — all state changes flow through PlacementController.
    }
}
