//
//  ContentView.swift
//  StreamAnimation
//
//  Created by Christian J Clampitt on 9/26/25.
//

import SwiftUI

// MARK: - Test Project for Node/Edge Animation Synchronization Issue

struct ContentView: View {
    @State private var graph = GraphModel()

    var body: some View {
        ZStack {
            Color.gray.opacity(0.1)

            // Draw edges first (behind nodes)
            ForEach(graph.edges) { edge in
                EdgeView(edge: edge, graph: graph)
            }

            // Draw nodes
            ForEach(graph.nodes) { node in
                NodeView(model: node)
            }

            // Controls
            VStack {
                Spacer()
                Button("Animate") {
                    graph.randomizeGraph()
                }
                .padding()
            }
        }
    }
}

// MARK: - Graph Model

@Observable
class GraphModel {
    var nodes: [NodeModel] = []
    var edges: [EdgeModel] = []

    init() {
        // Start with initial nodes
        let nodeA = NodeModel(id: "A", position: CGPoint(x: 100, y: 150))
        let nodeB = NodeModel(id: "B", position: CGPoint(x: 400, y: 350))
        nodes = [nodeA, nodeB]

        // Start with initial edge - no position capture at creation time
        let initialEdge = EdgeModel(fromNodeID: "A", toNodeID: "B")
        edges = [initialEdge]
    }

    func randomizeGraph() {
        withAnimation(.linear(duration: 0.3)) {
            // Determine which nodes will remain
            let newNodeCount = Int.random(in: 2...6)
            let keepExistingNodes = min(newNodeCount, nodes.count)
            let nodesToKeep = Array(nodes.prefix(keepExistingNodes))
            let nodeIDsToKeep = Set(nodesToKeep.map { $0.id })

            // Mark edges for removal and set up collapse animations
            for edge in edges {
                let fromNodeExists = nodeIDsToKeep.contains(edge.fromNodeID)
                let toNodeExists = nodeIDsToKeep.contains(edge.toNodeID)

                if !fromNodeExists && !toNodeExists {
                    // Both nodes disappearing - collapse to center
                    edge.setupCenterCollapse(graph: self)
                } else if !fromNodeExists {
                    // From node disappearing - collapse to destination
                    edge.setupCollapseToDestination(graph: self)
                } else if !toNodeExists {
                    // To node disappearing - collapse to source
                    edge.setupCollapseToSource(graph: self)
                }
            }

            // Update nodes - reposition existing, add new ones
            var newNodes: [NodeModel] = []

            // Keep some existing nodes and reposition them
            for node in nodesToKeep {
                node.position = randomPosition()
                newNodes.append(node)
            }

            // Add new nodes
            for _ in newNodes.count..<newNodeCount {
                let nodeID = availableNodeID()
                let newNode = NodeModel(id: nodeID, position: randomPosition())
                newNodes.append(newNode)
            }

            nodes = newNodes

            // Remove edges that should be gone (after animation completes)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.edges.removeAll { edge in
                    let fromExists = nodeIDsToKeep.contains(edge.fromNodeID)
                    let toExists = nodeIDsToKeep.contains(edge.toNodeID)
                    return !fromExists || !toExists
                }
            }

            // Add some random new edges
            let edgeCount = Int.random(in: 1...min(4, newNodes.count - 1))
            for _ in 0..<edgeCount {
                guard let fromNode = newNodes.randomElement() else { continue }

                // Filter out same node and nodes too close together
                let validTargets = newNodes.filter { targetNode in
                    targetNode.id != fromNode.id &&
                    abs(targetNode.position.x - fromNode.position.x) >= 100 // Minimum distance
                }

                guard let toNode = validTargets.randomElement() else { continue }

                // Avoid duplicate edges
                let edgeExists = edges.contains { edge in
                    (edge.fromNodeID == fromNode.id && edge.toNodeID == toNode.id) ||
                    (edge.fromNodeID == toNode.id && edge.toNodeID == fromNode.id)
                }

                if !edgeExists {
                    let newEdge = EdgeModel(fromNodeID: fromNode.id, toNodeID: toNode.id)
                    edges.append(newEdge)
                }
            }
        }
    }

    func node(withID id: String) -> NodeModel? {
        nodes.first { $0.id == id }
    }
}

// MARK: - Edge Model

@Observable
class EdgeModel: Identifiable {
    let id = UUID()
    let fromNodeID: String
    let toNodeID: String

    // Captured positions for normal operation
    var normalFromPoint: CGPoint?
    var normalToPoint: CGPoint?

    // Collapse animation state
    var collapseFrom: CGPoint?
    var collapseTo: CGPoint?
    var isCollapsing = false

    init(fromNodeID: String, toNodeID: String) {
        self.fromNodeID = fromNodeID
        self.toNodeID = toNodeID
    }

    func captureCurrentPositions(graph: GraphModel) {
        guard let fromNode = graph.node(withID: fromNodeID),
              let toNode = graph.node(withID: toNodeID) else { return }

        normalFromPoint = fromNode.outputAnchor
        normalToPoint = toNode.inputAnchor
    }

    func setupCenterCollapse(graph: GraphModel) {
        // Capture current positions before any nodes are removed
        captureCurrentPositions(graph: graph)

        guard let normalFrom = normalFromPoint,
              let normalTo = normalToPoint else { return }

        let centerPoint = CGPoint(
            x: (normalFrom.x + normalTo.x) / 2,
            y: (normalFrom.y + normalTo.y) / 2
        )

        collapseFrom = centerPoint
        collapseTo = centerPoint
        isCollapsing = true
    }

    func setupCollapseToSource(graph: GraphModel) {
        // Capture current positions before any nodes are removed
        captureCurrentPositions(graph: graph)

        guard let normalFrom = normalFromPoint else { return }

        collapseFrom = normalFrom
        collapseTo = normalFrom
        isCollapsing = true
    }

    func setupCollapseToDestination(graph: GraphModel) {
        // Capture current positions before any nodes are removed
        captureCurrentPositions(graph: graph)

        guard let normalTo = normalToPoint else { return }

        collapseFrom = normalTo
        collapseTo = normalTo
        isCollapsing = true
    }

    func currentFromPoint(graph: GraphModel) -> CGPoint {
        if isCollapsing, let collapseFrom = collapseFrom {
            return collapseFrom
        }

        // For normal (non-collapsing) edges, always use live node positions
        if let fromNode = graph.node(withID: fromNodeID) {
            return fromNode.outputAnchor
        }

        // If node doesn't exist and we're not collapsing, this is an error state
        // Should not happen in normal operation
        return CGPoint.zero
    }

    func currentToPoint(graph: GraphModel) -> CGPoint {
        if isCollapsing, let collapseTo = collapseTo {
            return collapseTo
        }

        // For normal (non-collapsing) edges, always use live node positions
        if let toNode = graph.node(withID: toNodeID) {
            return toNode.inputAnchor
        }

        // If node doesn't exist and we're not collapsing, this is an error state
        // Should not happen in normal operation
        return CGPoint.zero
    }
}

// MARK: - Node Model

@Observable
class NodeModel: Identifiable {
    let id: String
    var position: CGPoint

    init(id: String, position: CGPoint) {
        self.id = id
        self.position = position
    }

    // Node is 100x50, so input is at -50, output at +50 from center
    var inputAnchor: CGPoint {
        CGPoint(x: position.x - 50, y: position.y)
    }

    var outputAnchor: CGPoint {
        CGPoint(x: position.x + 50, y: position.y)
    }

    // SOLUTION: Create animating versions that use the position value for animation
    var animatingInputAnchor: CGPoint {
        CGPoint(x: position.x - 50, y: position.y)
    }

    var animatingOutputAnchor: CGPoint {
        CGPoint(x: position.x + 50, y: position.y)
    }
}

// MARK: - Node View

struct NodeView: View {
    var model: NodeModel

    var body: some View {
        Rectangle()
            .fill(Color.blue.opacity(0.7))
            .frame(width: 100, height: 50)
            .position(model.position)
            .overlay(
                Text(model.id)
                    .foregroundColor(.white)
                    .position(model.position)
            )
    }
}

// MARK: - Edge View

struct EdgeView: View {
    let edge: EdgeModel
    let graph: GraphModel

    var body: some View {
        AnimatableEdgeLine(
            from: edge.currentFromPoint(graph: graph),
            to: edge.currentToPoint(graph: graph)
        )
        .stroke(Color.purple, lineWidth: 6)
        .opacity(edge.isCollapsing ? 0.5 : 1.0)
    }
}

// MARK: - Animatable Edge Shape

struct AnimatableEdgeLine: Shape {
    var from: CGPoint
    var to: CGPoint

    // This is absolutely required to redraw the Path smoothly
    var animatableData: AnimatablePair<AnimatablePair<Double, Double>, AnimatablePair<Double, Double>> {
        get {
            AnimatablePair(
                AnimatablePair(from.x, from.y),
                AnimatablePair(to.x, to.y)
            )
        }
        set {
            from.x = newValue.first.first
            from.y = newValue.first.second
            to.x = newValue.second.first
            to.y = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: from)

            // More pronounced curve - extend control points beyond midpoint
            let distance = abs(to.x - from.x)
            let curveStrength = min(distance * 0.6, 150) // Scale curve with distance, max 150

            let controlPoint1 = CGPoint(x: from.x + curveStrength, y: from.y)
            let controlPoint2 = CGPoint(x: to.x - curveStrength, y: to.y)

            path.addCurve(to: to, control1: controlPoint1, control2: controlPoint2)
        }
    }
}

// MARK: - Additional Graph Utilities

extension GraphModel {
    func randomPosition() -> CGPoint {
        CGPoint(
            x: Double.random(in: 50...350),
            y: Double.random(in: 100...500)
        )
    }

    func availableNodeID() -> String {
        let usedIDs = Set(nodes.map { $0.id })
        for i in 0..<26 {
            let id = String(UnicodeScalar(65 + i)!) // A, B, C, D...
            if !usedIDs.contains(id) {
                return id
            }
        }
        return "Z" // Fallback
    }
}

#Preview {
    ContentView()
}
