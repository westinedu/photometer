//
//  PhotoTableAdapter.swift
//  Photometer
//
//  Created by Morten Just Petersen on 12/21/15.
//  Copyright © 2015 Morten Just Petersen. All rights reserved.
//

import UIKit
import CoreLocation
import Photos

protocol PhotoTableAdapterDelegate {
    func PhotoTableWantsFetchUpdate()
}

class PhotoTableAdapter: NSObject, UITableViewDelegate, UITableViewDataSource, PhotoCellDelegate, UIScrollViewDelegate {
    var photoTable : UITableView!
    var allPhotos:[MeterImage] = [MeterImage]()
    var adapterDelegate : PhotoTableAdapterDelegate?
    var vc : ViewController!
    var locationManager:CLLocationManager!
    var currentBg = UIColor.darkGrayColor()
    
    
    init(p:UITableView) {
        super.init()
        self.photoTable = p
        setBgForScrollPosition(photoTable.contentOffset.y)
    }
    
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = (allPhotos.count * 2) - 1 + 1 // +1 is for the top photo which is the live one
        return count
    }
    
    func rowIsPhoto(rowNumber:Int) -> Bool {
        return rowNumber%2 == 0 ? true : false
    }
    
    func meterImageForIndexPath(indexPath:NSIndexPath) -> MeterImage {
        let photoId = (indexPath.row+1)/2 - 1
        return allPhotos[photoId]
        
    }

    func getPhotoCellForIndexPath(indexPath:NSIndexPath) -> UITableViewCell {
        let photo = photoTable.dequeueReusableCellWithIdentifier("photoCell")! as! PhotoCell
        photo.resetAllLabels()
        
        let manager = PHCachingImageManager.defaultManager()
        if photo.tag != 0 {
            manager.cancelImageRequest(PHImageRequestID(photo.tag))
        }
        

        let currentPhoto = meterImageForIndexPath(indexPath)
        
        photo.meterImage = currentPhoto
        photo.updateTimeTaken(currentPhoto.creationDate)
        
       let imageSize = CGSizeMake(128, 128)
        photo.tag = Int(manager.requestImageForAsset(currentPhoto.asset, targetSize: imageSize, contentMode: .AspectFill, options: nil, resultHandler: { (resultImage, _) -> Void in
            
            if let image = resultImage {
                photo.didEnterViewPort()
                photo.photo.image = image
            } else {
                print("\(photo.tag) is bad.")
            }
        }))        

        return photo
    }
    
    func photoCellWantsTableUpdate() {
        adapterDelegate?.PhotoTableWantsFetchUpdate()
    }
    
    func getLivePhotoCell()->UITableViewCell{
        let photo = photoTable.dequeueReusableCellWithIdentifier("photoCell")! as! PhotoCell
        photo.delegate = self
        photo.showCameraButton()
        photo.resetAllLabels()
        photo.updateTimeTaken(NSDate())
        photo.vc = self.vc
        return photo
    }
    
    func getIntervalCellForIndexPath(indexPath:NSIndexPath) -> UITableViewCell {
        let interval = photoTable.dequeueReusableCellWithIdentifier("intervalCell")! as! IntervalCell
        interval.resetAllLabels()
        let intervalTimes = getTimestampsForIntervalCell(indexPath.row-2)
        interval.updateElapsedTimeFromStartAndEndTimes(intervalTimes.start, end: intervalTimes.end)
        if let locations = getLocationsForIntervalCell(indexPath.row-2) {
            interval.updateLocationDistanceFromStartAndEndLocations(locations.start, end: locations.end)
            interval.updateAltitudeDifference(locations.start, end: locations.end)
        }

        interval.setTopLabelColorFromBackgroundColor(currentBg)
        
        return interval
    }
    
    func getLiveIntervalCell()->UITableViewCell{
        let interval = photoTable.dequeueReusableCellWithIdentifier("intervalCell")! as! IntervalCell
        interval.resetAllLabels()
        let mostRecentPhotoTimestamp = getMostRecentTimestamp()
        interval.beginTimerFrom(mostRecentPhotoTimestamp)

        print("setting label based on \(currentBg)")
        interval.setTopLabelColorFromBackgroundColor(currentBg)
        return interval
    }
    

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
             return getLivePhotoCell()
        }
        if indexPath.row == 1 {
            return getLiveIntervalCell()
        }
        
        if rowIsPhoto(indexPath.row) {
            return getPhotoCellForIndexPath(indexPath)
        } else {
            return getIntervalCellForIndexPath(indexPath)
        }
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if rowIsPhoto(indexPath.row){
            return 128
        } else {
            return 180
        }
    }
    
    func tableView(tableView: UITableView, didEndDisplayingCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        if !rowIsPhoto(indexPath.row){
            let intervalCell = cell as! IntervalCell
            intervalCell.stopTimer()
        } else {
            let photoCell = cell as! PhotoCell
            photoCell.leaveViewPort()
        }
    }
    
    func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        
        if indexPath.row == 0 {
            locationManager = CLLocationManager()
            locationManager.requestWhenInUseAuthorization()
        }
        
        if !rowIsPhoto(indexPath.row){
            let interval = cell as! IntervalCell
            interval.prepareForViewport()
        }
}
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if !rowIsPhoto(indexPath.row){return}
        print("Did select")
    }
    
    func tableView(tableView: UITableView, didHighlightRowAtIndexPath indexPath: NSIndexPath) {
        print("highlight row \(indexPath.row)")
        if(indexPath.row != 0){
            vc.selectedMeterImage = meterImageForIndexPath(indexPath)
            }
    }
    

    func getLocationsForIntervalCell(cellIndex:Int) -> (start:CLLocation, end:CLLocation)? {
        let aboveIndex = ((cellIndex-1) + 1) / 2
        let belowIndex = ((cellIndex+1) + 1) / 2
        
        if let end = allPhotos[aboveIndex].location {
            if let start = allPhotos[belowIndex].location {
                return(start:start, end:end)
            }
        }
        return nil
    }
    
    func getMostRecentTimestamp() -> NSDate {
        let mostRecentIndex = 0
        return allPhotos[mostRecentIndex].creationDate
    }
    
    func getTimestampsForIntervalCell(cellIndex:Int) -> (start:NSDate, end:NSDate){
        let aboveIndex = ((cellIndex-1) + 1) / 2
        let belowIndex = ((cellIndex+1) + 1) / 2
        let start = allPhotos[belowIndex].creationDate
        let end = allPhotos[aboveIndex].creationDate
        return(start:start, end:end)
     }
    
    // Mark: Scrollview color when scrolling
    
    func setBgForScrollPosition(y:CGFloat){
        let pos = y
        let slowedDownPos = pos * 0.005
        let h:CGFloat = (slowedDownPos % 100) / 100
        let s:CGFloat = 1.0
        let b:CGFloat = 0.07
        let bg = UIColor(hue: h, saturation: s, brightness: b, alpha: 1)
        currentBg = bg
        photoTable.backgroundColor = bg
    }
    
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        setBgForScrollPosition(scrollView.contentOffset.y)
    }
}
