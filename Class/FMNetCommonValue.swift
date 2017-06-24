//
//  FMNetDownload.swift
//  SwiftSQLite
//
//  Created by 周发明 on 17/6/17.
//  Copyright © 2017年 周发明. All rights reserved.
//

import UIKit
// 网络请求完成的回调闭包

typealias FMNetCompleteHandle = (FMNetCompleteValue) -> ()

// 下载的监听
typealias FMNetDownloadProgressBlock = (Float) -> ()

struct FMNetDownload {
    public let downloadTask: URLSessionDownloadTask
    public let filePath : String
    public let identify: String
    public let progressBlock: FMNetDownloadProgressBlock
    public let completeHandle: FMNetCompleteHandle
}

// 上传的监听
typealias FMNetUploadProgressBlock = (Float) -> ()


struct FMNetUpload {
    public var uploadTask: URLSessionUploadTask?
    public let progressBlock: FMNetUploadProgressBlock
    public let completeHandle: FMNetCompleteHandle
}


// 回调完成的错误
enum FMNetError {
    case systemError(Error)
    case customError(String)
}
// 回调的结果
enum FMNetCompleteValue {
    case success(Any,String?)
    case failure(FMNetError,String?)
    
    public func successValue() -> Any? {
        switch self {
        case let .success(any):
            return any
        default:
            return nil
        }
    }
    
    public func errorDoman() -> String {
        switch self {
        case .success(_, _):
            return ""
        case .failure(let error, _):
            switch error {
            case .systemError(let serror):
                return serror.localizedDescription
            case .customError(let cerror):
                return cerror
            }
        }
    }
    
}
