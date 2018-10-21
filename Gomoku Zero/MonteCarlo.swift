//
//  MonteCarlo.swift
//  Gomoku Zero
//
//  Created by Jiachen Ren on 10/20/18.
//  Copyright © 2018 Jiachen Ren. All rights reserved.
//

import Foundation

class MonteCarloCortex: CortexProtocol {
    var delegate: CortexDelegate
    
    var heuristicEvaluator = HeuristicEvaluator()
    var randomExpansion = true
    var maxSimulationDepth = 20
    
    // BasicCortex for performing fast simulation.
    var basicCortex: BasicCortex
    
    /// The exploration factor
    static let expFactor: Double = sqrt(2.0)
    
    /// The branching factor
    var breadth: Int
    
    init(_ delegate: CortexDelegate, breadth: Int) {
        self.delegate = delegate
        self.breadth = breadth
        self.basicCortex = BasicCortex(delegate)
        heuristicEvaluator.delegate = self
    }
    
    /// Expansion phase
    func expand(_ node: Node) -> Node {
        var moves: [Move]!
        if let retrieved = Zobrist.orderedMovesMap[zobrist] {
            moves = retrieved
        } else {
            moves = [genSortedMoves(for: .black, num: breadth), genSortedMoves(for: .white, num: breadth)]
                .flatMap({$0})
            if randomExpansion { moves = moves.shuffled() }
            else { moves = moves.sorted(by: {$0.score > $1.score}) }
            ZeroPlus.syncedQueue.sync {
                Zobrist.orderedMovesMap[Zobrist(zobrist: zobrist)] = moves
            }
        }
        let idx = node.children.count // The index of the next node to be explored
        let newNode = Node(parent: node, identity: delegate.curPlayer, co: moves[idx].co)
        node.children.append(newNode)
        return newNode
    }
    
    func getMove() -> Move {
        let rootNode = Node(identity: delegate.curPlayer, co: (0,0))
        while !timeout() {
            let node = rootNode.select(breadth)
            let stackTrace = node.stackTrace()
            for node in stackTrace {
                delegate.put(at: node.coordinate!)
            }
            let newNode = expand(node)
            let player = playout(node: newNode)
            newNode.backpropagate(winner: player)
            revert(num: stackTrace.count)
        }
        
        var bestNode: Node?
        for node in rootNode.children {
            if bestNode == nil {
                bestNode = node
            } else if node.numVisits > bestNode!.numVisits {
                bestNode = node
            }
        }
        return (bestNode!.coordinate!, bestNode!.numVisits)
    }
    
    func revert(num: Int) {
        for _ in 0..<num {
            delegate.revert()
        }
    }
    
    /**
     Performs quick simulation with target node
     - Returns: null for draw, .black if black emerges as winner.
     */
    func playout(node: Node) -> Piece? {
        delegate.put(at: node.coordinate!)
        for i in 0..<maxSimulationDepth {
            let move = basicCortex.getMove(for: delegate.curPlayer)
            delegate.put(at: move.co)
            if let winner = delegate.hasWinner() {
                revert(num: i)
                return winner
            }
        }
        revert(num: maxSimulationDepth + 1)
        return nil
    }
    
    func checkGameState() {
        
    }
    
    /// Monte Carlo Tree Node
    class Node {
        var numWins: Int = 0
        var numVisits: Int = 0
        var identity: Piece
        var coordinate: Coordinate?
        var children = [Node]()
        var parent: Node?
        
        convenience init(identity: Piece, co: Coordinate) {
            self.init(parent: nil, identity: identity, co: co)
        }
        
        init(parent: Node?, identity: Piece, co: Coordinate) {
            self.parent = parent
            self.identity = identity
            self.coordinate = co
        }
        
        /// Trace up the search tree; root node is excluded.
        func stackTrace() -> [Node] {
            var stack = [Node]()
            var node = self
            while node.parent != nil {
                stack.append(node)
                node = node.parent!
            }
            
            return stack
        }
        
        /// Recursive selection phase
        func select(_ breadth: Int) -> Node {
            if children.count < breadth {
                return self // If the current node is not fully expanded, stop selection.
            }
            var selected = children[0]
            var maxUcb1 = children[0].ucb1()
            for idx in 1..<children.count {
                let node = children[idx]
                let ucb1 = node.ucb1()
                if ucb1 > maxUcb1 {
                    maxUcb1 = ucb1
                    selected = children[idx]
                }
            }
            
            return selected.select(breadth)
        }
        
        /// Upper Confidence Bound 1 algorithm, used to balance exploiration and exploration
        func ucb1() -> Double {
            let exploitation = Double(numWins) / Double(numVisits)
            let exploration = MonteCarloCortex.expFactor * sqrt(log(Double(parent!.numVisits)) / log(M_E) / Double(numVisits))
            return exploitation + exploration
        }
        
        /**
         Backpropagation: update the stats of all nodes that were traversed to get to the current node
         */
        func backpropagate(winner: Piece?) {
            if let player = winner {
                numWins += player == identity ? 0 : 1
            }
            numVisits += 1
            if let parent = self.parent {
                parent.backpropagate(winner: winner)
            }
        }
    }
    
}
