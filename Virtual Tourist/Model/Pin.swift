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
    
    struct Config {
        static let flickrURLTemplate = ["https://farm", "{farm-id}", ".staticflickr.com/", "{server-id}", "/", "{id}", "_", "{secret}", "_z.jpg"]
        static let SearchURL = "https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=fab57d67573d42d644953ca8b54c7f6e&format=json&nojsoncallback=1"
        static let Radius = 5 /* kilometers */
        static let Limit = 36
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
        searchFlickr { (count) -> Void in
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
    
    // MARK: - Flickr
    
    func buildFlickrUrl(photo: [String: AnyObject]) -> String {
        var photoUrlParts = Config.flickrURLTemplate
        photoUrlParts[1] = String(photo["farm"] as! Int)
        photoUrlParts[3] = photo["server"] as! String
        photoUrlParts[5] = photo["id"] as! String
        photoUrlParts[7] = photo["secret"] as! String
        
        return photoUrlParts.joinWithSeparator("")
    }
    
    func searchFlickr(completionHandler: ((count: Int) -> Void)?) {
        let url = "\(Config.SearchURL)&lat=\(coordinate.latitude)&lon=\(coordinate.longitude)&radius=\(Config.Radius)&per_page=\(Config.Limit)&page=\(page)"
        let request = NSURLRequest(URL: NSURL(string: url)!)
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { data, response, error in
            guard error == nil else {
                completionHandler?(count: 0)
                return
            }
            guard data != nil else {
                completionHandler?(count: 0)
                return
            }
            let count = self.savePhotos(data!)
            completionHandler?(count: count)
        }
        task.resume()
    }
    
    func savePhotos(data: NSData) -> Int {
        var count = 0
        do {
            let result = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            if let photoData = result["photos"] as? [String: AnyObject] {
                if let photos = photoData["photo"] as? [AnyObject] {
                    for photo in photos {
                        let file = photo["id"] as! String
                        let photoUrl = buildFlickrUrl(photo as! [String : AnyObject])
                        let dict = ["url": photoUrl, "file": file, "pin": self]
                        _ = Photo(dictionary: dict, context: self.managedObjectContext!)
                        do {
                            try self.managedObjectContext?.save()
                        } catch {
                            print("Error savePhotos():", error)
                        }
                        count++
                    }
                    return count
                }
            }
        } catch {
        }
        return count
    }
    
}
