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
                EdgeView(edge: edge)
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

        // Start with initial edge
        let initialEdge = EdgeModel(fromNodeID: "A", toNodeID: "B")
        edges = [initialEdge]

        // Initialize edge's animated points to current positions
        initialEdge.initializeAnimatedPoints(graph: self)
    }

    func randomizeGraph() {
        // PHASE 1 (0.0-0.1s): Retract all edges
        for edge in edges {
            edge.retract()
        }

        // PHASE 2 (0.5-1.0s): Reposition nodes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.linear(duration: 0.5)) {
                // Determine which nodes will remain
                let newNodeCount = Int.random(in: 2...6)
                let keepExistingNodes = min(newNodeCount, self.nodes.count)
                let nodesToKeep = Array(self.nodes.prefix(keepExistingNodes))
                let nodeIDsToKeep = Set(nodesToKeep.map { $0.id })

                // Update nodes - reposition existing, add new ones
                var newNodes: [NodeModel] = []

                // Keep some existing nodes and reposition them
                for node in nodesToKeep {
                    node.position = self.randomPosition()
                    newNodes.append(node)
                }

                // Add new nodes
                for _ in newNodes.count..<newNodeCount {
                    let nodeID = self.availableNodeID()
                    let newNode = NodeModel(id: nodeID, position: self.randomPosition())
                    newNodes.append(newNode)
                }

                self.nodes = newNodes

                // Remove edges whose nodes are gone
                self.edges.removeAll { edge in
                    let fromExists = nodeIDsToKeep.contains(edge.fromNodeID)
                    let toExists = nodeIDsToKeep.contains(edge.toNodeID)
                    return !fromExists || !toExists
                }

                // Create new edges
                let edgeCount = Int.random(in: 1...min(4, newNodes.count - 1))
                for _ in 0..<edgeCount {
                    guard let fromNode = newNodes.randomElement() else { continue }

                    // Filter out same node and nodes too close together
                    let validTargets = newNodes.filter { targetNode in
                        targetNode.id != fromNode.id &&
                        abs(targetNode.position.x - fromNode.position.x) >= 100
                    }

                    guard let toNode = validTargets.randomElement() else { continue }

                    // Avoid duplicate edges
                    let edgeExists = self.edges.contains { edge in
                        (edge.fromNodeID == fromNode.id && edge.toNodeID == toNode.id) ||
                        (edge.fromNodeID == toNode.id && edge.toNodeID == fromNode.id)
                    }

                    if !edgeExists {
                        let newEdge = EdgeModel(fromNodeID: fromNode.id, toNodeID: toNode.id)
                        // Initialize at retracted state (from point = to point)
                        newEdge.animatedFromPoint = fromNode.outputAnchor
                        newEdge.animatedToPoint = fromNode.outputAnchor
                        self.edges.append(newEdge)
                    }
                }
            }
        }

        // PHASE 3 (1.0-1.5s): Extend all edges
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            for edge in self.edges {
                edge.extend(graph: self)
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

    // Animatable edge points - these drive the visual appearance
    var animatedFromPoint: CGPoint = CGPoint.zero
    var animatedToPoint: CGPoint = CGPoint.zero

    init(fromNodeID: String, toNodeID: String) {
        self.fromNodeID = fromNodeID
        self.toNodeID = toNodeID
    }

    // Get the current anchor points from the graph
    func liveFromPoint(graph: GraphModel) -> CGPoint {
        return graph.node(withID: fromNodeID)?.outputAnchor ?? CGPoint.zero
    }

    func liveToPoint(graph: GraphModel) -> CGPoint {
        return graph.node(withID: toNodeID)?.inputAnchor ?? CGPoint.zero
    }

    // Initialize animated points to match current node positions
    func initializeAnimatedPoints(graph: GraphModel) {
        animatedFromPoint = liveFromPoint(graph: graph)
        animatedToPoint = liveToPoint(graph: graph)
    }

    // Retract: animate to-point toward from-point
    func retract() {
        withAnimation(.linear(duration: 0.5)) {
            animatedToPoint = animatedFromPoint
        }
    }

    // Extend: animate drawing from source to destination
    func extend(graph: GraphModel) {
        // Set both points to source position first (reset state)
        animatedFromPoint = liveFromPoint(graph: graph)
        animatedToPoint = liveFromPoint(graph: graph)

        // Then animate only the destination point to target
        withAnimation(.linear(duration: 0.5)) {
            animatedToPoint = liveToPoint(graph: graph)
        }
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

    var body: some View {
        AnimatableEdgeLine(
            from: edge.animatedFromPoint,
            to: edge.animatedToPoint
        )
        .stroke(Color.purple, lineWidth: 6)
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
