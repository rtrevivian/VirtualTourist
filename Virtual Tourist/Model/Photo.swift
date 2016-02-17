//
//  Photo.swift
//  Virtual Tourist
//
//  Created by Richard Trevivian on 2/12/16.
//  Copyright © 2016 Richard Trevivian. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import CoreLocation

enum DownloadStatus {
    case NotLoaded, Loading, Loaded
}

@objc(Photo)
class Photo: NSManagedObject {
    
    struct Keys {
        static let URL = "url"
        static let File = "file"
        static let Pin = "pin"
    }
    
    struct Notification {
        static let Loaded = "PhotoLoaded"
    }
    
    // MARK: - Properties
    
    @NSManaged var url: String
    @NSManaged var file: String
    @NSManaged var pin: Pin
    
    var downloadStatus: DownloadStatus = .NotLoaded
    
    // MARK: - Initialization
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        if let _ = ImageCache.sharedInstance().imageWithIdentifier(file) {
            downloadStatus = .Loaded
        }
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)
        super.init(entity: entity!, insertIntoManagedObjectContext: context)
        
        url = dictionary[Keys.URL] as! String
        file = dictionary[Keys.File] as! String
        pin = dictionary[Keys.Pin] as! Pin
    }
    
    // MARK: - Methods
    
    func saveImage(image: UIImage) {
        ImageCache.sharedInstance().storeImage(image, withIdentifier: file)
        downloadStatus = .Loaded
        NSNotificationCenter.defaultCenter().postNotificationName(Notification.Loaded, object: self)
    }
    
    func delete() {
        ImageCache.sharedInstance().deleteImage(self.file)
        managedObjectContext?.deleteObject(self)
        do {
            try managedObjectContext?.save()
        } catch {
            print("Error delete():", error)
        }
    }
    
}
