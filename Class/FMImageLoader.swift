//
//  FMImageLoader.swift
//  SwiftSQLite
//
//  Created by 周发明 on 17/6/22.
//  Copyright © 2017年 周发明. All rights reserved.
//

import Foundation
import UIKit

typealias FMImageLoaderCompleteHandle = (FMImageLoaderResult) -> ()

enum FMImageLoaderOperationState{
    case success
    case failure
    case underway
}

struct FMImageLoaderError {
    let errorDomain: String
}

enum FMImageLoaderResult{
    case success(UIImage)
    case underway(UIImage?)
    case failure(FMImageLoaderError)
}

struct FMImageLoaderOperation {
    var operation: Operation? = nil
    let url: URL
    var progress: Float = 0.0
    var state: FMImageLoaderOperationState = .underway
}

class FMImageLoader: NSObject {
    
    static let shareLoader = FMImageLoader()
    
    let imagePathFolder: String
    
    fileprivate override init() {
        var imagePath = NSHomeDirectory()
        imagePath.append("/Library/FMImageLoaderDiskCache")
        if !FileManager.default.fileExists(atPath: imagePath) {
            try? FileManager.default.createDirectory(atPath: imagePath, withIntermediateDirectories: true, attributes: nil)
        }
        self.imagePathFolder = imagePath
    }
    
    func fm_loadImage(url: URL, placehoderImage: UIImage?, progressBlock: @escaping (Float) -> () = {(progress) in }, completeHandle: @escaping FMImageLoaderCompleteHandle) -> Void {
        
        DispatchQueue.global().async {
            let image = self.loadCacheImage(url: url)
            // 从缓存中取
            if image != nil {
                print("从缓存中读取成功")
                let result = FMImageLoaderResult.success(image!)
                completeHandle(result)
                return
            }
            print("从缓存中读取失败")
            // 缓存没有  看看是否正在下载
            let operation = self.oprations[url.fm_md5()]
            // 正在下载就返回
            if operation != nil {
                return
            }
            // 即将开始下载   有占位图片显示占位图片
            if placehoderImage != nil {
                completeHandle(FMImageLoaderResult.underway(placehoderImage))
            }
            
            self.beginStarDownload(url: url, progressBlock: progressBlock, completeHandle: completeHandle)
        }
    }
    
    func beginStarDownload(url: URL, progressBlock: @escaping (Float) -> () = {(progress) in }, completeHandle: @escaping FMImageLoaderCompleteHandle) -> Void {
        
        var download = FMImageLoaderOperation(operation: nil, url: url, progress: 0, state: .underway)
        // 即将开始下载
        
        let fileTargetPath = self.imagePathFolder.appending("/\(url.fm_imageName())")
        
        let operationDownload = BlockOperation {
            FMNetManager.shareManager.downloadFile(url: url.absoluteString, fileTargetPath: fileTargetPath, progressBlock: progressBlock, completeHandle: { (result) in
                var downloadIn: FMImageLoaderOperation
                var complete: FMImageLoaderResult
                switch result{
                case .success(let imagePath, let idy):
                    downloadIn = self.oprations[idy!.fm_md5]!
                    downloadIn.state = .success
                    let image = UIImage(contentsOfFile: imagePath as! String)!
                    self.imageCache.setObject(image, forKey: url.fm_imageName() as AnyObject)
                    complete = FMImageLoaderResult.success(image)
                    break
                case.failure(let error, let idy):
                    downloadIn = self.oprations[idy!.fm_md5]!
                    downloadIn.state = .failure
                    var errorDomain: String
                    switch error{
                    case .systemError(let serror):
                        errorDomain = serror.localizedDescription
                        break
                    case .customError(let cerror):
                        errorDomain = cerror
                        break
                    }
                    complete = FMImageLoaderResult.failure(FMImageLoaderError(errorDomain: errorDomain))
                    break
                }
                completeHandle(complete)
            })
        }
        
        download.operation = operationDownload
        
        self.oprations[url.fm_md5()] = download
        
        self.loadImageQueue.addOperation(operationDownload)
    }
    
    lazy var oprations: [String: FMImageLoaderOperation] = {
        return [String: FMImageLoaderOperation]()
    }()
    
    lazy var imageCache: NSCache = {
        return NSCache<AnyObject, AnyObject>()
    }()
    
    lazy var loadImageQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "FMImageLoader.loadImageQueue"
        queue.maxConcurrentOperationCount = 5
        return queue
    }()
}

extension FMImageLoader{
    func loadCacheImage(url: URL) -> UIImage? {
        var image = self.loadMemoryCacheImage(url: url)
        if image == nil {
            image = self.loadDiskCacheImage(url: url)
        }
        return image
    }
    
    func loadMemoryCacheImage(url: URL) -> UIImage? {
        let exsit = self.imageCache.object(forKey: url.fm_imageName() as AnyObject)
        return exsit as? UIImage
    }
    
    func loadDiskCacheImage(url: URL) -> UIImage? {
        let path = self.imagePathFolder.appending("/\(url.fm_imageName())")
        if FileManager.default.fileExists(atPath: path){
            return UIImage(contentsOfFile: path)
        }
        return nil
    }
}


extension URL{
    
    func fm_md5() -> String {
        return self.absoluteString.fm_md5
    }
    
    func fm_imageName() -> String {
        return self.fm_md5().appending(".jpg")
    }
}

protocol FMImageLoaderProtocol{
    
}

extension FMImageLoaderProtocol {
    
    func fm_loadImage(url: URL, placehoderImage: UIImage?, progressBlock: @escaping (Float) -> (), placehoderShow: @escaping () -> (Bool),mainQueue: @escaping (UIImage) -> ()) -> Void{
        FMImageLoader.shareLoader.fm_loadImage(url: url, placehoderImage: placehoderImage, progressBlock: progressBlock, completeHandle: { (result) in
            switch result{
            case .success(let image):
                DispatchQueue.main.async {
                    mainQueue(image)
                }
                break
            case .underway(let image):
                if placehoderShow() {
                    DispatchQueue.main.async {
                        mainQueue(image!)
                    }
                }
                break
            default:
                break
            }
        })
    }
}

extension UIImageView: FMImageLoaderProtocol{
    func fm_loadImage(url: URL, placehoderImage: UIImage? = nil, progressBlock: @escaping (Float) -> () = {(progress) in }) -> Void {
        self.fm_loadImage(url: url, placehoderImage: placehoderImage, progressBlock: progressBlock, placehoderShow: { () -> (Bool) in
            return self.image == nil
        }) { (image) in
            self.image = image
        }
    }
}

extension UIButton: FMImageLoaderProtocol {
    func fm_loadImage(url: URL, placehoderImage: UIImage? = nil, state: UIControlState,progressBlock: @escaping (Float) -> () = {(progress) in }) -> Void {
        self.fm_loadImage(url: url, placehoderImage: placehoderImage, progressBlock: progressBlock, placehoderShow: { () -> (Bool) in
            return self.image(for: state) == nil
        }) { (image) in
            self.setImage(image, for: state)
        }
    }
    
    func fm_loadBgImage(url: URL, placehoderImage: UIImage? = nil, state: UIControlState,progressBlock: @escaping (Float) -> () = {(progress) in }) -> Void {
        self.fm_loadImage(url: url, placehoderImage: placehoderImage, progressBlock: progressBlock, placehoderShow: { () -> (Bool) in
            return self.backgroundImage(for: state) == nil
        }) { (image) in
            self.setBackgroundImage(image, for: state)
        }
    }
}
