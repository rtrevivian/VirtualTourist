//
//  ImageCache.swift
//  Virtual Tourist
//
//  Created by Richard Trevivian on 2/12/16.
//  Copyright © 2016 Richard Trevivian. All rights reserved.
//

import UIKit

class ImageCache {
    
    class func sharedInstance() -> ImageCache {
        struct Static {
            static let instance = ImageCache()
        }
        
        return Static.instance
    }
    
    func imageWithIdentifier(identifier: String?) -> UIImage? {
        
        // If the identifier is nil, or empty, return nil
        if identifier == nil || identifier! == "" {
            return nil
        }
        
        let path = pathForIdentifier(identifier!)
        if let data = NSData(contentsOfFile: path) {
            return UIImage(data: data)
        }
        
        return nil
    }
    
    func storeImage(image: UIImage?, withIdentifier identifier: String) {
        let path = pathForIdentifier(identifier)
        
        // If the image is nil, remove images from the cache
        if image == nil {
            do {
                try NSFileManager.defaultManager().removeItemAtPath(path)
            } catch {
                print("Error storeImage:", error)
            }
            return
        }
        if let data = UIImagePNGRepresentation(image!) {
            data.writeToFile(path, atomically: true)
        }
    }
    
    func deleteImage(identifier: String) {
        storeImage(nil, withIdentifier: identifier)
    }
    
    func pathForIdentifier(identifier: String) -> String {
        if let documentsDirectoryURL: NSURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first! {
            let fullURL = documentsDirectoryURL.URLByAppendingPathComponent(identifier)
            return fullURL.path!
        } else {
            return ""
        }
    }
    
    func downloadImage(imageUrl: String, completionHandler: ((imageData: NSData?, error: NSError?) ->  Void)?) -> NSURLSessionTask {
        let url = NSURL(string: imageUrl)!
        let request = NSURLRequest(URL: url)
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) {data, response, downloadError in
            if let error = downloadError {
                completionHandler?(imageData: nil, error: error)
            } else {
                completionHandler?(imageData: data, error: nil)
            }
            /*
            // Count files stored in DocumentDirectory
            let path = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first?.path
            do {
                let files = try NSFileManager.defaultManager().contentsOfDirectoryAtPath(path!)
                print(files.count, "files found")
            } catch {
                print("Error downloadImage", error)
            }
            */
        }
        task.resume()
        return task
    }
    
}
