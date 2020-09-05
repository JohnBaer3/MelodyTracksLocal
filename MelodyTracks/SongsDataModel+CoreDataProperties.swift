//
//  SongsDataModel+CoreDataProperties.swift
//  
//
//  Created by John Baer on 9/2/20.
//
//

import Foundation
import CoreData


extension SongsDataModel {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SongsDataModel> {
        return NSFetchRequest<SongsDataModel>(entityName: "SongsDataModel")
    }

    @NSManaged public var songsURL: String?
    @NSManaged public var songsBPM: String?

}
