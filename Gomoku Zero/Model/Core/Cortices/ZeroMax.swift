//
//  ZeroMax.swift
//  Gomoku Zero
//
//  Created by Jiachen Ren on 10/21/18.
//  Copyright © 2018 Jiachen Ren. All rights reserved.
//

import Foundation

/// A variant of minimax that attempts to address the horizon effect
class ZeroMax: MinimaxCortex {

    var basicCortex: BasicCortex
    
    /// An Int b/w 0 and 100 that denotes the probability in which a simulation should be performed.
    var rolloutPr: Int
    
    /// Defaults to Threat.interesting. Denotes the threshold beyond which a simulation might be performed.
    var threshold: Int
    
    /// Simulation deph during rollout.
    var simDepth: Int
    
    var status: Status = .search
    
    /**
     - Parameter rollout: an integer b/w 0 and 100 that denotes the probability of simulation at leaf nodes.
     - Parameter threshold: defaults to Threat.interesting. Denotes the threshold beyond which a simulation might be performed.
     - Parameter simDepth: depth of rollouts to be carried. Defaults to 10.
     */
    init(_ delegate: CortexDelegate, depth: Int, breadth: Int, rollout: Int, threshold: Int = Threat.interesting, simDepth: Int = 10) {
        self.basicCortex = BasicCortex(delegate)
        self.rolloutPr = rollout
        self.threshold  = threshold
        self.simDepth = simDepth
        super.init(delegate, depth: depth, breadth: breadth)
    }
    
    override func getMove() -> Move {
        let move = super.getMove()
        if verbose {
            print("rollout probability: \(rolloutPr)")
        }
        return move
    }
    
    /**
     A modification to the minimax algorithm that attempts to address the horizon effect.
     It attempts to look beyond the horizon by playing out a full simulation
     of the current leaf node game state until a winner emerges.
     Otherwise, there is nothing beyond the horizon and the original heuristic value is returned.
     
     - Returns: modified heuristic value of the node.
     */
    override func beyondHorizon(of score: Int, alpha: Int, beta: Int, player: Piece) -> Int {
        // Overcome horizon effect by looking further into interesting nodes
        var score = score
        let shouldRollout = rolloutPr != 0 && Int.random(in: 0...(100 - rolloutPr)) == 0
        if let co = delegate.revert() {
            let white = Threat.analyze(for: .black, at: co, pieces: zobrist.matrix)
            let black = Threat.analyze(for: .white, at: co, pieces: zobrist.matrix)
            let threatPotential = [white, black].flatMap{$0}
                .map{$0.rawValue}.sorted(by: >)[0]
            delegate.put(at: co)
            if abs(threatPotential) > threshold && shouldRollout && status != .kill {
                status = .kill
                if let rolloutScore = minimax(depth: simDepth, player: player, alpha: alpha, beta: beta)?.score {
                    score = rolloutScore
                }
                status = .search
            }
        }
        return score
    }
    
    override func getCandidates() -> [Move] {
        switch status {
        case .search: return super.getCandidates()
        case .kill: return super.getCandidates().filter{$0.score > threshold}
        }
    }
    
    enum Status {
        case search
        case kill
    }
}
