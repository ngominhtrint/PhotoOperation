//
//  PhotoOperations.swift
//  PhotoOperation
//
//  Created by TriNgo on 1/14/19.
//  Copyright © 2019 RoverDream. All rights reserved.
//

import UIKit

// This enum contains all the posible states a photo record can be in
enum PhotoRecordState {
    case new, downloaded, filtered, failed
}

class PhotoRecord {
    let name: String
    let url: URL
    var state = PhotoRecordState.new
    var image = UIImage(named: "Placeholder")
    
    init(name: String, url: URL) {
        self.name = name
        self.url = url
    }
}

class PendingOperations {
    lazy var downloadInProgress = [IndexPath: Operation]()
    lazy var downloadQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "Download Queue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    lazy var filterationsInProgress = [IndexPath: Operation]()
    lazy var filterationQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "Image Filteration Queue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
}

class ImageDownloader: Operation {
    
    let photoRecord: PhotoRecord
    
    init(photoRecord: PhotoRecord) {
        self.photoRecord = photoRecord
    }
    
    override func main() {
        if self.isCancelled {
            return
        }
        
        let imageData = NSData(contentsOf: self.photoRecord.url as URL)
        
        if self.isCancelled {
            return
        }
        
        if (imageData?.length)! > 0 {
            self.photoRecord.image = UIImage(data: imageData! as Data)
            self.photoRecord.state = .downloaded
        } else {
            self.photoRecord.state = .failed
            self.photoRecord.image = UIImage(named: "failed")
        }
    }
}

class ImageFilteration: Operation {
    
    let photoRecord: PhotoRecord
    
    init(photoRecord: PhotoRecord) {
        self.photoRecord = photoRecord
    }
    
    override func main() {
        if self.isCancelled {
            return
        }
        
        if self.photoRecord.state != .downloaded {
            return
        }
        
        if let filteredImage = self.applySepiaFilter(image: self.photoRecord.image!) {
            self.photoRecord.image = filteredImage
            self.photoRecord.state = .filtered
        }
    }
    
    func applySepiaFilter(image: UIImage) -> UIImage? {
        let inputImage = CIImage.init(data: image.pngData()!)
        
        if self.isCancelled {
            return nil
        }
        
        let context = CIContext(options: nil)
        let filter = CIFilter(name: "CISepiaTone")
        filter?.setValue(inputImage, forKey: kCIInputImageKey)
        filter?.setValue(0.8, forKey: "inputIntensity")
        let outputImage = filter?.outputImage
        
        if self.isCancelled {
            return nil
        }
        
        let outImage = context.createCGImage(outputImage!, from: outputImage!.extent)
        let returnImage = UIImage(cgImage: outImage!)
        return returnImage
    }
}
