//
//  PhotoAlbumViewController.swift
//  Virtual Tourist
//
//  Created by Richard Trevivian on 2/12/16.
//  Copyright © 2016 Richard Trevivian. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class PhotoAlbumViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, NSFetchedResultsControllerDelegate {
    
    // MARK: - Outlets
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var newCollectionButton: UIBarButtonItem!
    @IBOutlet weak var collectionLabel: UILabel!
    
    // MARK: - Properties
    
    lazy var sharedContext: NSManagedObjectContext = {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }()
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "url", ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "pin == %@", self.pin);
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
    }()
    
    var pin: Pin!
    
    // MARK: - View
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fetchedResultsController.delegate = self
        fetch()
        
        mapView.setRegion(MKCoordinateRegionMakeWithDistance(pin.coordinate, 2000, 2000), animated: true)
        mapView.addAnnotation(pin)
        
        collectionView.delegate = self
        collectionView.dataSource = self
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "onPinAllPhotosLoaded:", name: Pin.Notifications.AllPhotosLoaded, object: pin)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "onPhotoLoaded:", name: Photo.Notification.Loaded, object: nil)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.setToolbarHidden(false, animated: false)
        
        var allPhotosLoaded = true
        var noPhotosLoaded = true
        collectionLabel.text = "Loading"
        for photo in pin.photos {
            if photo.downloadStatus != .Loaded {
                allPhotosLoaded = false
            } else {
                noPhotosLoaded = false
            }
        }
        if noPhotosLoaded {
            dispatch_async(dispatch_get_main_queue()) {
                self.collectionLabel.text = "No Photos Found"
                self.collectionLabel.hidden = false
                self.newCollectionButton.enabled = false
            }
        } else if allPhotosLoaded {
            dispatch_async(dispatch_get_main_queue()) {
                self.collectionLabel.hidden = true
                self.newCollectionButton.enabled = true
            }
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    // MARK: - Fetched results controller
    
    func fetch() {
        do {
            try fetchedResultsController.performFetch()
        } catch {
            print("Error fetching \(error)")
        }
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        if type == .Delete {
            collectionView.deleteItemsAtIndexPaths([indexPath!])
        }
    }
    
    // MARK: - Collection view
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("photoCell", forIndexPath: indexPath) as! PhotoCell
        
        let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        cell.imageView.image = UIImage(named: "frame")
        cell.activityIndicator.startAnimating()
        if let image = ImageCache.sharedInstance().imageWithIdentifier(photo.file) {
            cell.activityIndicator.stopAnimating()
            cell.imageView.image = image
        } else if photo.downloadStatus == .NotLoaded {
            let task = ImageCache.sharedInstance().downloadImage(photo.file) { imageData, error in
                if imageData != nil {
                    let image = UIImage(data: imageData!)
                    photo.saveImage(image!)
                    cell.imageView.image = image
                    cell.activityIndicator.stopAnimating()
                } else {
                    dispatch_async(dispatch_get_main_queue()) {
                        print("error downloading image \(error)")
                        photo.delete()
                    }
                }
            }
            cell.taskToCancelifCellIsReused = task
        }
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section]
        return sectionInfo.numberOfObjects
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        if photo.downloadStatus == .Loaded {
            photo.delete()
        }
    }
    
    // MARK: - Buttons
    
    @IBAction func didPressNewCollection(sender: UIBarButtonItem) {
        newCollectionButton.enabled = false
        collectionLabel.hidden = false
        pin.deletePhotos()
        pin.loadPhotos(true) { numberFound in
            dispatch_async(dispatch_get_main_queue()) {
                self.collectionLabel.hidden = true
            }
            if numberFound > 0 {
                self.fetch()
            } else if self.pin.page > 1 {
                // cycle to the first page if we didn't find any more pictures
                self.pin.page = 0
                CoreDataStackManager.sharedInstance().saveContext()
                self.didPressNewCollection(self.newCollectionButton)
            }
        }
    }
    
    // MARK: - Notifications
    
    func onPinAllPhotosLoaded(sender: AnyObject) {
        dispatch_async(dispatch_get_main_queue()) {
            self.collectionLabel.hidden = true
            self.newCollectionButton.enabled = true
        }
    }
    
    func onPhotoLoaded(photo: Photo) {
        dispatch_async(dispatch_get_main_queue()) {
            self.collectionView.reloadData()
        }
    }
    
}
