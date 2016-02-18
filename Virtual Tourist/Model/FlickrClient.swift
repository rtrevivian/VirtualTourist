//
//  FlickrClient.swift
//  Virtual Tourist
//
//  Created by Richard Trevivian on 2/18/16.
//  Copyright © 2016 Richard Trevivian. All rights reserved.
//

import Foundation

class FlickrClient {
    
    struct Config {
        static let flickrURLTemplate = ["https://farm", "{farm-id}", ".staticflickr.com/", "{server-id}", "/", "{id}", "_", "{secret}", "_z.jpg"]
        static let SearchURL = "https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=fab57d67573d42d644953ca8b54c7f6e&format=json&nojsoncallback=1"
        static let Radius = 10 /* kilometers */
        static let Limit = 36
    }
    
    // MARK: - Methods
    
    class func buildFlickrUrl(photo: [String: AnyObject]) -> String {
        var photoUrlParts = Config.flickrURLTemplate
        photoUrlParts[1] = String(photo["farm"] as! Int)
        photoUrlParts[3] = photo["server"] as! String
        photoUrlParts[5] = photo["id"] as! String
        photoUrlParts[7] = photo["secret"] as! String
        
        return photoUrlParts.joinWithSeparator("")
    }
    
    class func searchFlickr(pin: Pin, completionHandler: ((count: Int) -> Void)?) {
        let url = "\(Config.SearchURL)&lat=\(pin.coordinate.latitude)&lon=\(pin.coordinate.longitude)&radius=\(Config.Radius)&per_page=\(Config.Limit)&page=\(pin.page)"
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
            let count = self.savePhotos(pin, data: data!)
            completionHandler?(count: count)
        }
        task.resume()
    }
    
    class func savePhotos(pin: Pin, data: NSData) -> Int {
        var count = 0
        do {
            let result = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            if let photoData = result["photos"] as? [String: AnyObject] {
                if let photos = photoData["photo"] as? [AnyObject] {
                    for photo in photos {
                        let file = photo["id"] as! String
                        let photoUrl = buildFlickrUrl(photo as! [String : AnyObject])
                        _ = Photo(dictionary: ["url": photoUrl, "file": file, "pin": pin], context: CoreDataStackManager.sharedInstance().managedObjectContext)
                        do {
                            try CoreDataStackManager.sharedInstance().managedObjectContext.save()
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
