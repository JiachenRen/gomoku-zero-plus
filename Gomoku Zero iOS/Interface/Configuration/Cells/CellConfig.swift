//
//  Cell.swift
//  Gomoku Zero iOS
//
//  Created by Jiachen Ren on 12/4/18.
//  Copyright © 2018 Jiachen Ren. All rights reserved.
//

import Foundation

class CellConfig {
    var id: String {
        return ""
    }
    var title: String
    
    
    init(title: String) {
        self.title = title
    }
}

class SwitchConfig: CellConfig {
    override var id: String {
        return "switch-cell"
    }
    
    var isOn: Bool
    
    init(title: String, isOn: Bool) {
        self.isOn = isOn
        super.init(title: title)
    }
}

class SegueConfig: CellConfig {
    override var id: String {
        return "segue-cell"
    }
    
    var subtitles: [String]
    var selectedIdx: Int
    var subtitle: String {
        return subtitles[selectedIdx]
    }
    
    init(title: String, selectedIdx: Int, subtitles: [String]) {
        self.selectedIdx = selectedIdx
        self.subtitles = subtitles
        super.init(title: title)
    }
}

class StepperConfig: CellConfig {
    override var id: String {
        return "stepper-cell"
    }
    
    var min: Double
    var max: Double
    var val: Double
    
    init(title: String, min: Double, max: Double, val: Double) {
        self.min = min
        self.max = max
        self.val = val
        super.init(title: title)
    }
}

class SegmentedConfig: SegueConfig {
    override var id: String {
        return "segmented-cell"
    }
}

class ToggleConfig: SwitchConfig {
    override var id: String {
        return "toggle-cell"
    }
}


