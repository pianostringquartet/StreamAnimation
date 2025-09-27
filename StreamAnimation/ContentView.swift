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
        // Start with initial nodes at temporary positions
        let nodeA = NodeModel(id: "A", position: CGPoint.zero)
        let nodeB = NodeModel(id: "B", position: CGPoint.zero)
        nodes = [nodeA, nodeB]

        // Start with initial edge
        let initialEdge = EdgeModel(fromNodeID: "A", toNodeID: "B")
        edges = [initialEdge]

        // Arrange nodes in tree layout
        arrangeNodesInTreeLayout()

        // Initialize edge's animated points to current positions
        initialEdge.initializeAnimatedPoints(graph: self)
    }

    func randomizeGraph() {
        // PHASE 1 (0.0-0.1s): Retract all edges
        for edge in edges {
            edge.retract()
        }

        // PHASE 2 (0.1-0.2s): Reposition nodes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.linear(duration: 0.1)) {
                // Determine which nodes will remain
                let newNodeCount = Int.random(in: 2...6)
                let keepExistingNodes = min(newNodeCount, self.nodes.count)
                let nodesToKeep = Array(self.nodes.prefix(keepExistingNodes))
                let nodeIDsToKeep = Set(nodesToKeep.map { $0.id })

                // Update nodes - reposition existing, add new ones
                var newNodes: [NodeModel] = []

                // Keep some existing nodes
                for node in nodesToKeep {
                    newNodes.append(node)
                }

                // Add new nodes
                for _ in newNodes.count..<newNodeCount {
                    let nodeID = self.availableNodeID()
                    let newNode = NodeModel(id: nodeID, position: CGPoint.zero) // Temporary position
                    newNodes.append(newNode)
                }

                self.nodes = newNodes

                // Arrange nodes in tree layout
                self.arrangeNodesInTreeLayout()

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

                    // Filter out same node only (tree layout handles spacing)
                    let validTargets = newNodes.filter { targetNode in
                        targetNode.id != fromNode.id
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

        // PHASE 3 (0.2-0.3s): Extend all edges
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
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
        withAnimation(.linear(duration: 0.1)) {
            animatedToPoint = animatedFromPoint
        }
    }

    // Extend: animate drawing from source to destination
    func extend(graph: GraphModel) {
        // Set both points to source position first (reset state)
        animatedFromPoint = liveFromPoint(graph: graph)
        animatedToPoint = liveFromPoint(graph: graph)

        // Then animate only the destination point to target
        withAnimation(.linear(duration: 0.1)) {
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
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.blue)
            .frame(width: 100, height: 50)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            .position(model.position)
            .overlay(
                Text(model.id)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
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

// MARK: - Tree Layout System

struct TreeLevel {
    var nodes: [NodeModel] = []
    var yPosition: Double = 0
}

// MARK: - Additional Graph Utilities

extension GraphModel {
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

    // Check if a position collides with existing nodes
    func hasCollision(at position: CGPoint, excluding: NodeModel? = nil) -> Bool {
        let minDistance: Double = 120 // Minimum distance between node centers

        for node in nodes {
            if let excluding = excluding, node.id == excluding.id {
                continue
            }

            let distance = sqrt(pow(position.x - node.position.x, 2) + pow(position.y - node.position.y, 2))
            if distance < minDistance {
                return true
            }
        }
        return false
    }

    // Generate a safe position without collisions
    func safePosition(excluding: NodeModel? = nil) -> CGPoint {
        let maxAttempts = 20

        for _ in 0..<maxAttempts {
            let position = CGPoint(
                x: Double.random(in: 100...300), // Add padding from screen edges
                y: Double.random(in: 150...450)  // Add padding from screen edges
            )

            if !hasCollision(at: position, excluding: excluding) {
                return position
            }
        }

        // Fallback: grid positioning if random fails
        return findGridPosition(excluding: excluding)
    }

    // Fallback grid positioning
    private func findGridPosition(excluding: NodeModel? = nil) -> CGPoint {
        let gridSpacing: Double = 130
        let startX: Double = 115  // Add padding
        let startY: Double = 170  // Add padding

        for row in 0..<4 {
            for col in 0..<3 {
                let position = CGPoint(
                    x: startX + Double(col) * gridSpacing,
                    y: startY + Double(row) * gridSpacing
                )

                if !hasCollision(at: position, excluding: excluding) {
                    return position
                }
            }
        }

        // Final fallback
        return CGPoint(x: 200, y: 200)
    }

    // Build tree structure and assign levels
    func buildTreeLevels() -> [TreeLevel] {
        var levels: [TreeLevel] = []
        var nodeToLevel: [String: Int] = [:]
        var visited: Set<String> = []

        // Find root nodes (nodes with no incoming edges)
        let hasIncomingEdge = Set(edges.map { $0.toNodeID })
        let rootNodes = nodes.filter { !hasIncomingEdge.contains($0.id) }

        // If no clear roots, pick first few nodes as roots
        let actualRoots = rootNodes.isEmpty ? Array(nodes.prefix(min(2, nodes.count))) : rootNodes

        // Assign root level with padding
        if !actualRoots.isEmpty {
            levels.append(TreeLevel(nodes: actualRoots, yPosition: 170)) // Add top padding
            for root in actualRoots {
                nodeToLevel[root.id] = 0
                visited.insert(root.id)
            }
        }

        // Build subsequent levels using BFS-like approach
        var currentLevel = 0
        while visited.count < nodes.count && currentLevel < 5 { // Max 5 levels
            var nextLevelNodes: [NodeModel] = []

            // Find nodes that are children of current level nodes
            for edge in edges {
                if nodeToLevel[edge.fromNodeID] == currentLevel && !visited.contains(edge.toNodeID) {
                    if let childNode = nodes.first(where: { $0.id == edge.toNodeID }) {
                        nextLevelNodes.append(childNode)
                        nodeToLevel[edge.toNodeID] = currentLevel + 1
                        visited.insert(edge.toNodeID)
                    }
                }
            }

            if !nextLevelNodes.isEmpty {
                let yPos = 170 + Double(currentLevel + 1) * 120 // 120px between levels, with padding
                levels.append(TreeLevel(nodes: nextLevelNodes, yPosition: yPos))
            }

            currentLevel += 1
        }

        // Add any remaining unvisited nodes to final level
        let unvisitedNodes = nodes.filter { !visited.contains($0.id) }
        if !unvisitedNodes.isEmpty {
            let yPos = levels.isEmpty ? 170 : levels.last!.yPosition + 120 // With padding
            levels.append(TreeLevel(nodes: unvisitedNodes, yPosition: yPos))
        }

        return levels
    }

    // Position nodes in tree layout
    func arrangeNodesInTreeLayout() {
        let levels = buildTreeLevels()

        for level in levels {
            let nodeCount = level.nodes.count
            let screenWidth: Double = 400
            let availableWidth = screenWidth - 100 // Leave 50px padding on each side
            let totalNodeWidth = Double(nodeCount) * 100 // Node width
            let totalSpacing = max(0, Double(nodeCount - 1) * 30) // 30px spacing between nodes
            let totalWidth = totalNodeWidth + totalSpacing

            let startX = 50 + (availableWidth - totalWidth) / 2 // Center with padding

            for (index, node) in level.nodes.enumerated() {
                let xPos = startX + Double(index) * (100 + 30) // Node width + spacing
                node.position = CGPoint(x: xPos, y: level.yPosition)
            }
        }
    }
}

#Preview {
    ContentView()
}
