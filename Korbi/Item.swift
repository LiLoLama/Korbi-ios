//
//  Item.swift
//  Korbi
//
//  Created by Liam Schmid on 23.10.25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
