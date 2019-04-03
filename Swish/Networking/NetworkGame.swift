//
//  NetworkGame.swift
//  Swish
//
//  Created by Jugal Jain on 4/2/19.
//  Copyright © 2019 Cazamere Comrie. All rights reserved.
//

struct NetworkGame: Hashable {
    var name: String
    private var locationId: Int
    
    var location: GameTableLocation {
        return GameTableLocation.location(with: locationId)
    }
    
    init(name: String? = nil, locationId: Int = 0) {
        self.name = name ?? ""
        self.locationId = locationId
    }
}

struct GameTableLocation: Equatable, Hashable {
    let identifier: Int
    let name: String
    
    private init(identifier: Int) {
        self.identifier = identifier
        self.name = "Table \(self.identifier)"
    }
    
    private static var locations: [Int: GameTableLocation] = [:]
    static func location(with identifier: Int) -> GameTableLocation {
        if let location = locations[identifier] {
            return location
        }
        
        let location = GameTableLocation(identifier: identifier)
        locations[identifier] = location
        return location
    }
    
    static func == (lhs: GameTableLocation, rhs: GameTableLocation) -> Bool {
        return lhs.identifier == rhs.identifier
    }
    
    func hash(into hasher: inout Hasher) {
        identifier.hash(into: &hasher)
    }
}
