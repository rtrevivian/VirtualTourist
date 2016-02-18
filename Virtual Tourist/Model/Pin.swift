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
        FlickrClient.searchFlickr(self) { (data) -> Void in
            guard data != nil else {
                return
            }
            do {
                let result = try NSJSONSerialization.JSONObjectWithData(data!, options: .AllowFragments)
                if let photoData = result["photos"] as? [String: AnyObject] {
                    if let photos = photoData["photo"] as? [AnyObject] {
                        for photo in photos {
                            let file = photo["id"] as! String
                            let photoUrl = FlickrClient.buildFlickrUrl(photo as! [String : AnyObject])
                            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                                let _ = Photo(dictionary: [Photo.Keys.URL: photoUrl, Photo.Keys.File: file, Photo.Keys.Pin: self], context: CoreDataStackManager.sharedInstance().managedObjectContext)
                                do {
                                    try CoreDataStackManager.sharedInstance().managedObjectContext.save()
                                } catch {
                                    print("Error savePhotos():", error)
                                }
                            })
                        }
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            if photos.count > 0 {
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
                        })
                    }
                }
            } catch {
                print("Error parsing json", error)
            }
        }
    }
    
    func deletePhotos() {
        for photo in photos {
            photo.delete()
        }
    }
    
}
