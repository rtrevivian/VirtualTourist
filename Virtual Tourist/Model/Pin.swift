//
//  Pin.swift
//  Virtual Tourist
//
//  Created by Richard Trevivian on 2/12/16.
//  Copyright © 2016 Richard Trevivian. All rights reserved.
//

import Foundation
import CoreData
import MapKit

@objc(Pin)
class Pin: NSManagedObject, MKAnnotation {
    
    struct Keys {
        static let Latitude = "latitude"
        static let Longitude = "longitude"
    }
    
    struct Notifications {
        static let Deleted = "PinDeleted"
        static let AllPhotosLoaded = "PinAllPhotosLoaded"
    }
    
    // MARK: - Properties
    
    @NSManaged var latitude: NSNumber
    @NSManaged var longitude: NSNumber
    @NSManaged var photos: [Photo]
    @NSManaged var page: Int
    
    var coordinate: CLLocationCoordinate2D {
        get {
            return CLLocationCoordinate2DMake(latitude as Double, longitude as Double)
        }
    }
    
    // MARK: - Initialization
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)
        super.init(entity: entity!, insertIntoManagedObjectContext: context)
        
        latitude = dictionary[Keys.Latitude] as! Double
        longitude = dictionary[Keys.Longitude] as! Double
        page = 1
    }
    
    // MARK: - Pin
    
    func deletePin() {
        deletePhotos()
        managedObjectContext!.deleteObject(self)
        do {
            try managedObjectContext?.save()
            NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: Notifications.Deleted, object: self))
        } catch {
            print("Error deletePin():", error)
        }
    }
    
    // MARK: - Photos
    
    func loadPhotos(getNextPage: Bool = false, completionHandler: ((numberFound: Int) -> Void)?) {
        if getNextPage {
            page++
        }
        FlickrClient.searchFlickr(self) { (count) -> Void in
            if count > 0 {
                var unloadedPhotos = self.photos.count
                for photo in self.photos {
                    photo.downloadStatus = .Loading
                    _ = ImageCache.sharedInstance().downloadImage(photo.url) { imageData, error in
                        unloadedPhotos--
                        guard imageData != nil else {
                            return
                        }
                        let image = UIImage(data: imageData!)
                        photo.saveImage(image!)
                        if unloadedPhotos == 0 {
                            NSNotificationCenter.defaultCenter().postNotificationName(Notifications.AllPhotosLoaded, object: self)
                        }
                    }
                }
            }
        }
    }
    
    func deletePhotos() {
        for photo in photos {
            photo.delete()
        }
    }
    
}
