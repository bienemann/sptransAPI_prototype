//
//  GTFSTrip.swift
//  sptransAPI
//
//  Created by resource on 8/2/16.
//  Copyright © 2016 bienemann. All rights reserved.
//

import Foundation
import RealmSwift

class GTFSTrip: GTFSBaseModel {
    
    dynamic var route_id : String = ""
    dynamic var service_id : String = ""
    dynamic var trip_id : String = ""
    dynamic var trip_headsign : String? = nil
    dynamic var trip_short_name : String? = nil
    let direction_id = RealmOptional<Int>()
    dynamic var block_id : String? = nil
    let shape_id = RealmOptional<Int>()
    let wheelchair_accessible = RealmOptional<Int>()
    let bikes_allowed = RealmOptional<Int>()
    
    override static func primaryKey() -> String? {
        return "trip_id"
    }
    
    override class func typecast() -> ((String, AnyObject) -> AnyObject) {
        return { (key,value) in
            
//            switch key {
//            case "direction_id": fallthrough
//            case "shape_id":
//                if value is NSNumber {
//                    return value.intValue!
//                }else{ return value }
//            default:
                return value
//            }
            
        }
    }
    
// Specify properties to ignore (Realm won't persist these)
    
//  override static func ignoredProperties() -> [String] {
//    return []
//  }
}
