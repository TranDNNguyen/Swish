//
//  CodablePosition.swift
//  Swish
//
//  Created by Neil Natekar on 5/8/19.
//  Copyright © 2019 Cazamere Comrie. All rights reserved.
//

import Foundation

class CodablePosition: Codable{
    var dim1: Float
    var dim2: Float
    var dim3: Float
    var dim4: Float
    
    // only working with 3d space
    init(dim1: Float, dim2: Float, dim3: Float, dim4: Float){
        self.dim1 = dim1
        self.dim2 = dim2
        self.dim3 = dim3
        self.dim4 = dim4
    }
}
