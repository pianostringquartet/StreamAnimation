//
//  FixedRecursiveDictionaryTest_Realistic.swift
//  Standalone test with REALISTIC parameters (not millions of nodes)
//

import Foundation
import Testing

// MARK: - Test Types

struct TestNode {
    let id: UUID
    var data: String
    var nested: [TestNestedData]
}

struct TestNestedData {
    let values: [TestInputValue]
    let children: [TestLayerData]?
}

struct TestInputValue {
    let coordinate: UUID
    let payload: String
}

struct TestLayerData {
    let id: String
    let inputs: [TestNestedData]
    let children: [TestLayerData]?
}

// MARK: - Dictionary Extension

extension Dictionary where Key == UUID, Value == TestNode {
    mutating func updateNode(
        id: UUID,
        value: String,
        otherDict: inout [String: [UUID]]
    ) throws {
        guard var node = self[id] else { return }
        node.data = value
        self[id] = node
        otherDict[value] = [id]
    }
}

// MARK: - Tests

struct RealisticRecursiveDictionaryTest {

    // BROKEN VERSION (like your original code)
    @Test func testBrokenApproach_Realistic() throws {

        func createNodesBroken(
            layers: [TestLayerData],
            parentId: UUID?,
            nodesDict: inout [UUID: TestNode],
            connections: inout [String: [UUID]],
            depth: Int = 0
        ) throws {
            // BROKEN: nested forEach with mutations
            layers.forEach { layer in
                let nodeId = UUID()
                let entity = TestNode(
                    id: nodeId,
                    data: layer.id,
                    nested: layer.inputs
                )

                nodesDict[nodeId] = entity  // Mutation #1

                layer.inputs.forEach { nestedData in  // Nested closure
                    nestedData.values.forEach { inputValue in  // More nesting
                        try! nodesDict.updateNode(  // Mutation #2 in nested closure
                            id: nodeId,
                            value: inputValue.payload,
                            otherDict: &connections
                        )
                    }
                }

                if let children = layer.children, !children.isEmpty {
                    try! createNodesBroken(  // Recurse while closures active
                        layers: children,
                        parentId: nodeId,
                        nodesDict: &nodesDict,
                        connections: &connections,
                        depth: depth + 1
                    )
                }
            }
        }

        // Realistic parameters: ~100 total nodes (like your actual crash)
        let testData = makeNestedLayers(depth: 4, breadth: 3)

        var nodesDict: [UUID: TestNode] = [:]
        var connections: [String: [UUID]] = [:]

        print("🔴 Testing BROKEN version (realistic params)...")
        let startTime = Date()

        try createNodesBroken(
            layers: testData,
            parentId: nil,
            nodesDict: &nodesDict,
            connections: &connections
        )

        let duration = Date().timeIntervalSince(startTime)
        print("   Broken version: \(nodesDict.count) nodes in \(String(format: "%.2f", duration))s")
    }

    // FIXED VERSION
    @Test func testFixedApproach_Realistic() throws {

        func createNodesFixed(
            layers: [TestLayerData],
            parentId: UUID?,
            nodesDict: inout [UUID: TestNode],
            connections: inout [String: [UUID]],
            depth: Int = 0
        ) throws {

            // PHASE 1: Collect all nodes (no mutations)
            var pendingNodes: [UUID: TestNode] = [:]
            var pendingUpdates: [(nodeId: UUID, updates: [(coordinate: UUID, payload: String)])] = []

            for layer in layers {
                let nodeId = UUID()
                let entity = TestNode(
                    id: nodeId,
                    data: layer.id,
                    nested: layer.inputs
                )

                pendingNodes[nodeId] = entity

                var updates: [(UUID, String)] = []
                for nestedData in layer.inputs {
                    for inputValue in nestedData.values {
                        updates.append((inputValue.coordinate, inputValue.payload))
                    }
                }

                if !updates.isEmpty {
                    pendingUpdates.append((nodeId, updates))
                }
            }

            // PHASE 2: Apply all nodes at once
            nodesDict.merge(pendingNodes) { _, new in new }

            // PHASE 3: Apply all updates
            for (nodeId, updates) in pendingUpdates {
                for (coordinate, payload) in updates {
                    try nodesDict.updateNode(
                        id: nodeId,
                        value: payload,
                        otherDict: &connections
                    )
                }
            }

            // PHASE 4: Recurse on children
            for layer in layers {
                if let children = layer.children, !children.isEmpty {
                    let nodeId = pendingNodes.first(where: { $0.value.data == layer.id })?.key ?? UUID()

                    try createNodesFixed(
                        layers: children,
                        parentId: nodeId,
                        nodesDict: &nodesDict,
                        connections: &connections,
                        depth: depth + 1
                    )
                }
            }
        }

        // Same realistic parameters
        let testData = makeNestedLayers(depth: 4, breadth: 3)

        var nodesDict: [UUID: TestNode] = [:]
        var connections: [String: [UUID]] = [:]

        print("✅ Testing FIXED version (realistic params)...")
        let startTime = Date()

        try createNodesFixed(
            layers: testData,
            parentId: nil,
            nodesDict: &nodesDict,
            connections: &connections
        )

        let duration = Date().timeIntervalSince(startTime)
        print("   Fixed version: \(nodesDict.count) nodes in \(String(format: "%.2f", duration))s")
    }

    // Helper to create test data
    func makeNestedLayers(depth: Int, breadth: Int) -> [TestLayerData] {
        guard depth > 0 else { return [] }

        return (0..<breadth).map { i in
            let inputs = (0..<5).map { j in
                TestNestedData(
                    values: (0..<3).map { k in
                        TestInputValue(
                            coordinate: UUID(),
                            payload: "data_\(depth)_\(i)_\(j)_\(k)"
                        )
                    },
                    children: nil
                )
            }

            return TestLayerData(
                id: "layer_\(depth)_\(i)",
                inputs: inputs,
                children: makeNestedLayers(depth: depth - 1, breadth: breadth)
            )
        }
    }
}
