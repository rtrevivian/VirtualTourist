//
//  TravelLocationsMapViewController.swift
//  Virtual Tourist
//
//  Created by Richard Trevivian on 2/12/16.
//  Copyright © 2016 Richard Trevivian. All rights reserved.
//

import CoreData
import MapKit
import UIKit

class TravelLocationsMapViewController: UIViewController, MKMapViewDelegate {
    
    struct Keys {
        static let latitude = "latitude"
        static let longitude = "longitude"
        static let region = "region"
        static let spanLatitude = "spanLatitude"
        static let spanLongitude = "spanLongitude"
    }
    
    struct Segues {
        static let photoAlbum = "seguePhotoAlbum"
    }
    
    // MARK: - Outlets

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var clearButton: UIBarButtonItem!
    
    // MARK: - Properties
    
    lazy var sharedContext: NSManagedObjectContext = {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }()
    
    var pins: [Pin]! {
        didSet {
            dispatch_async(dispatch_get_main_queue()) { () -> Void in
                self.clearButton.enabled = !self.pins.isEmpty
            }
        }
    }
    var floatingPin: MKPointAnnotation!
    
    // MARK: - View
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItem = editButtonItem()
        mapView.delegate = self
        
        // Restore map region
        if let regionDictionary = NSUserDefaults.standardUserDefaults().dictionaryForKey(Keys.region) {
            let region = MKCoordinateRegionMake(
                CLLocationCoordinate2DMake(
                    regionDictionary[Keys.latitude] as! Double,
                    regionDictionary[Keys.longitude] as! Double
                ),
                MKCoordinateSpanMake(
                    regionDictionary[Keys.spanLatitude] as! Double,
                    regionDictionary[Keys.spanLongitude] as! Double
                )
            )
            mapView.setRegion(region, animated: true)
        }
        
        pins = fetchAllPins()
        for pin in pins {
            mapView.addAnnotation(pin)
        }
        
        editing = false
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.setToolbarHidden(true, animated: false)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "onPinDeleted:", name: Pin.Notifications.Deleted, object: nil)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    // MARK: - Editing
    
    override func setEditing(editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            self.title = editing ? "Tap pins to delete" : "Virtual Tourist"
            self.navigationController?.setToolbarHidden(!editing, animated: true)
        }
    }
    
    // MARK: - Navigation
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == Segues.photoAlbum {
            if let controller = segue.destinationViewController as? PhotoAlbumViewController {
                if let pin = sender as? Pin {
                    controller.pin = pin
                }
            }
        }
    }
    
    // MARK: - Map view
    
    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
        mapView.deselectAnnotation(view.annotation, animated: false)
        if editing {
            if let pin = view.annotation as? Pin {
                pin.deletePin()
            }
        } else {
            performSegueWithIdentifier(Segues.photoAlbum, sender: view.annotation)
        }
    }
    
    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        
        // Save map region
        let region = mapView.region
        let regionDictionary = [
            Keys.latitude: region.center.latitude,
            Keys.longitude: region.center.longitude,
            Keys.spanLatitude: region.span.latitudeDelta,
            Keys.spanLongitude: region.span.longitudeDelta
        ]
        NSUserDefaults.standardUserDefaults().setObject(regionDictionary, forKey: Keys.region)
    }
    
    // MARK: - Pins
    
    func fetchAllPins() -> [Pin] {
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        var results = [AnyObject]()
        do {
            results = try sharedContext.executeFetchRequest(fetchRequest)
        } catch {
            print("Error fetchAllPins():", error)
        }
        return results as! [Pin]
    }
    
    func deletePins(removePins: [Pin]) {
        for pin in removePins {
            pin.deletePin()
        }
    }
    
    // MARK: - Buttons
    
    @IBAction func didTapClearButton(sender: UIBarButtonItem) {
        deletePins(pins)
        editing = false
    }
    
    // MARK: - Gestures
    
    @IBAction func didLongPress(sender: UILongPressGestureRecognizer) {
        if !editing {
            let viewLocation = sender.locationInView(mapView)
            let coordinate = mapView.convertPoint(viewLocation, toCoordinateFromView: mapView)
            if floatingPin == nil {
                floatingPin = MKPointAnnotation()
                mapView.addAnnotation(floatingPin)
            }
            floatingPin.coordinate = coordinate
            if sender.state == .Ended {
                let dictionary = [Pin.Keys.Longitude: coordinate.longitude, Pin.Keys.Latitude: coordinate.latitude]
                let pin = Pin(dictionary: dictionary, context: sharedContext)
                pin.loadPhotos() { count in }
                pins.append(pin)
                mapView.addAnnotation(pin)
                mapView.removeAnnotation(floatingPin)
                floatingPin = nil
                CoreDataStackManager.sharedInstance().saveContext()
            }
        }
    }
    
    // MARK: - Notifications
    
    func onPinDeleted(sender: NSNotification) {
        if let pin = sender.object as? Pin {
            if pins.contains(pin) {
                mapView.removeAnnotation(pins.removeAtIndex(pins.indexOf(pin)!))
            }
        }
    }

}
