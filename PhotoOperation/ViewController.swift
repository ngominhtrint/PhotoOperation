//
//  ViewController.swift
//  PhotoOperation
//
//  Created by TriNgo on 1/14/19.
//  Copyright © 2019 RoverDream. All rights reserved.
//

import UIKit
import CoreImage

let dataSourceUrl = URL.init(string: "http://www.raywenderlich.com/downloads/ClassicPhotosDictionary.plist")

class ViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    var photos = [PhotoRecord]()
    let pendingOperations = PendingOperations()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        tableView.dataSource = self
        tableView.delegate = self
        
        fetchPhotoDetails()
    }

    func fetchPhotoDetails() {
        let request = URLRequest(url: dataSourceUrl!)
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        NSURLConnection.sendAsynchronousRequest(request, queue: OperationQueue.main) { response, data, error in
            if data != nil {
                let datasourceDictionary = try! PropertyListSerialization.propertyList(from: data!, options: [], format: nil) as! NSDictionary
                
                for (_, value) in datasourceDictionary.enumerated() {
                    let name = String(describing: value.key)
                    print("key : \(name) , value: \(value)")
                    let url = URL(string: value.value as? String ?? "")
                    if name != nil && url != nil {
                        let photoRecord = PhotoRecord(name:name, url: url!)
                        self.photos.append(photoRecord)
                    }
                }
                
                self.tableView.reloadData()
            }
            
            if error != nil {
                let alert = UIAlertView(title: "Oops!", message: error?.localizedDescription, delegate: nil, cancelButtonTitle: "OK")
                alert.show()
            }
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
        }
    }
}

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return photos.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CellIdentifier", for: indexPath)
        
        if cell.accessoryView == nil {
            let indicator = UIActivityIndicatorView.init(style: .gray)
            cell.accessoryView = indicator
        }
        
        let indicator = cell.accessoryView as! UIActivityIndicatorView
        
        let photoDetails = photos[indexPath.row]
        
        cell.textLabel?.text = photoDetails.name
        cell.imageView?.image = photoDetails.image
        
        switch photoDetails.state {
        case .filtered:
            indicator.stopAnimating()
        case .failed:
            indicator.stopAnimating()
            cell.textLabel?.text = "Failed to load"
        case .new, .downloaded:
            indicator.startAnimating()
            if (!tableView.isDragging && !tableView.isDecelerating) {
                self.startOperationsForPhotoRecord(photoDetails: photoDetails, indexPath: indexPath)
            }
        }
        return cell
    }
    
    func startOperationsForPhotoRecord(photoDetails: PhotoRecord, indexPath: IndexPath) {
        switch photoDetails.state {
        case .new:
            startDownloadForRecord(photoDetails: photoDetails, indexPath: indexPath)
        case .downloaded:
            startFilterationForRecord(photoDetails: photoDetails, indexPath: indexPath)
        default:
            NSLog("do nothing")
        }
    }
    
    func startDownloadForRecord(photoDetails: PhotoRecord, indexPath: IndexPath) {
        if pendingOperations.downloadInProgress[indexPath] != nil {
            return
        }
        
        let downloader = ImageDownloader(photoRecord: photoDetails)
        
        downloader.completionBlock = {
            if downloader.isCancelled {
                return
            }
            
            DispatchQueue.main.async {
                self.pendingOperations.downloadInProgress.removeValue(forKey: indexPath)
                self.tableView.reloadRows(at: [indexPath], with: .fade)
            }
        }
        
        pendingOperations.downloadInProgress[indexPath] = downloader
        pendingOperations.downloadQueue.addOperation(downloader)
    }
    
    func startFilterationForRecord(photoDetails: PhotoRecord, indexPath: IndexPath) {
        if pendingOperations.filterationsInProgress[indexPath] != nil {
            return
        }
        
        let filterer = ImageFilteration(photoRecord: photoDetails)
        filterer.completionBlock = {
            if filterer.isCancelled {
                return
            }
            
            DispatchQueue.main.async {
                self.pendingOperations.filterationsInProgress.removeValue(forKey: indexPath)
                self.tableView.reloadRows(at: [indexPath], with: .fade)
            }
        }
        
        pendingOperations.filterationsInProgress[indexPath] = filterer
        pendingOperations.filterationQueue.addOperation(filterer)
    }
    
}

extension ViewController: UIScrollViewDelegate, UITableViewDelegate {
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        suspendAllOperations()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            loadImagesForOnScreenCells()
            resumeAllOperations()
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        loadImagesForOnScreenCells()
        resumeAllOperations()
    }
    
    func suspendAllOperations() {
        pendingOperations.downloadQueue.isSuspended = true
        pendingOperations.filterationQueue.isSuspended = true
    }
    
    func resumeAllOperations() {
        pendingOperations.downloadQueue.isSuspended = false
        pendingOperations.filterationQueue.isSuspended = false
    }
    
    func loadImagesForOnScreenCells() {
        if let pathsArray = tableView.indexPathsForVisibleRows {
            var allPendingOperations = Set(Array(pendingOperations.downloadInProgress.keys))
            allPendingOperations.formUnion(Set(Array(pendingOperations.downloadInProgress.keys)))
            
            var toBeCancelled = allPendingOperations
            let visiblePaths = Set(pathsArray)
            toBeCancelled.subtract(visiblePaths as Set<IndexPath>)
            
            var toBeStarted = visiblePaths
            toBeStarted.subtract(allPendingOperations as Set<IndexPath>)
            
            for indexPath in toBeCancelled {
                if let pendingDownload = pendingOperations.downloadInProgress[indexPath] {
                    pendingDownload.cancel()
                }
                pendingOperations.downloadInProgress.removeValue(forKey: indexPath)
                if let pendingFilteration = pendingOperations.filterationsInProgress[indexPath] {
                    pendingFilteration.cancel()
                }
                pendingOperations.filterationsInProgress.removeValue(forKey: indexPath)
            }
            
            for indexPath in toBeStarted {
                let recordToProcess = self.photos[indexPath.row]
                startOperationsForPhotoRecord(photoDetails: recordToProcess, indexPath: indexPath)
            }
        }
    }
}

