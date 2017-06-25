//
//  FMNetManager.swift
//  SwiftSQLite
//
//  Created by 周发明 on 17/6/14.
//  Copyright © 2017年 周发明. All rights reserved.
//

import Foundation

// 请求的方法
enum FMNetMethod: String {
    case GET = "GET"
    case POST = "POST"
}

protocol FMNetManagerProtocol {
    func timeOut() -> TimeInterval
}

extension FMNetManagerProtocol{
    func timeOut() -> TimeInterval {
        return 60
    }
}

class FMNetManager: NSObject, FMNetManagerProtocol {
    
    static let shareManager = FMNetManager()

    private override init() {
        super.init()
    }
    // MARK -- 一般的post请求
    func post(baseUrl: String, urlPath: String, para: [String: Any]?, completeHandle: @escaping FMNetCompleteHandle) -> Void {
        self.request(method: .POST, baseUrl: baseUrl, urlPath: urlPath, para: para, completeHandle: completeHandle)
    }
    
    // MARK -- 一般的get请求
    func get(baseUrl: String, urlPath: String, para: [String: Any]?, completeHandle: @escaping FMNetCompleteHandle) -> Void {
        self.request(method: .GET, baseUrl: baseUrl, urlPath: urlPath, para: para, completeHandle: completeHandle)
    }
    
    // MARK -- 下载文件
    func downloadFile(url: String, fileTargetPath: String, progressBlock:@escaping FMNetDownloadProgressBlock,completeHandle: @escaping FMNetCompleteHandle) -> Void {
        let downloadTask = net_session.downloadTask(with: URL(string: url)!)
        self.dowmloadindItems[downloadTask] = FMNetDownload(downloadTask: downloadTask, filePath: fileTargetPath, identify: url, progressBlock: progressBlock, completeHandle: completeHandle)
        downloadTask.resume()
    }
    
    // MARK -- 上传文件
    func uploadFile(url: String, filePath: String, progressBlock: @escaping FMNetUploadProgressBlock, completeHandle: @escaping FMNetCompleteHandle) -> Void {
        self.uploadFile(url: url, para: nil, filePath: filePath, progressBlock: progressBlock, completeHandle: completeHandle)
    }
    
    // MARK -- 上传文件
    func uploadFile(url: String, para:[String : Any]?, filePath: String, progressBlock: @escaping FMNetUploadProgressBlock, completeHandle: @escaping FMNetCompleteHandle) -> Void {
        self .uploadFile(url: url, para: para, fileUrl: URL(fileURLWithPath: filePath), progressBlock: progressBlock, completeHandle: completeHandle)
    }
    
    // MARK -- 上传文件
    func uploadFile(url: String, para:[String : Any]?, fileUrl: URL, progressBlock: @escaping FMNetUploadProgressBlock, completeHandle: @escaping FMNetCompleteHandle) -> Void {
        guard let data = try? Data(contentsOf: fileUrl) else {
            let complete: FMNetCompleteValue
            let error = FMNetError.customError("路劲没有文件")
            complete = FMNetCompleteValue.failure(error,nil)
            completeHandle(complete)
            return
        }
        self .uploadFile(url: url, para: para, fileData: data, progressBlock: progressBlock, completeHandle: completeHandle)
    }
    
    // MARK -- 上传文件
    func uploadFile(url: String, para:[String : Any]?, fileData: Data, progressBlock: @escaping FMNetUploadProgressBlock, completeHandle: @escaping FMNetCompleteHandle) -> Void {
        var lastUrl = url
        let paraString = self.getStringFromPara(para: para)
        if (paraString.characters.count > 0) {
            lastUrl.append("?")
            lastUrl.append(paraString)
        }
        let uploadData = self.uploadRequest(url: lastUrl, fileData: fileData)
        
        var upload = FMNetUpload(uploadTask: nil, progressBlock: progressBlock, completeHandle: completeHandle)
        
        weak var weakSelf = self
        let uploadTask = net_session.uploadTask(with: uploadData.uploadRequest , from: uploadData.bodyData) { (data, response, error) in
            weakSelf?.completeHanle(data: data, response: response, error: error, uploadTask: upload.uploadTask,handle: completeHandle)
        }
        
        upload.uploadTask = uploadTask
        self.uploadindItems[uploadTask] = upload
        uploadTask.resume()
    }
    
    // MARK -- 最终的获取数据的方法
    private func request(method: FMNetMethod, baseUrl: String, urlPath: String, para: [String: Any]?, completeHandle: @escaping FMNetCompleteHandle){

        let url = URL(string: "\(baseUrl)\(urlPath)")
        var request: URLRequest
        let paraString = self.getStringFromPara(para: para)
        switch method {
        case .GET:
            request = URLRequest(url: URL(string: "\(url?.absoluteString)?\(paraString)")!)
            break
        case .POST:
            request = URLRequest(url: url!)
            request.httpMethod = method.rawValue
            let data = paraString.data(using: .utf8)
            request.httpBody = data
            break
        }
        
        weak var weakSelf = self
        
        let dataTask = net_session.dataTask(with: request) { (data, respose, error) in
            weakSelf?.completeHanle(data: data, response: respose, error: error, uploadTask: nil, handle: completeHandle)
        }
        
        dataTask.resume()
    }
    // MARK -- 根据字典获取拼接完成的字符串
    func getStringFromPara(para: [String: Any]?) -> String {
        var paraString: String = ""
        guard let para = para else {
            return paraString;
        }
        if para.count > 0 {
            var index: Int = 0
            for pa in para {
                paraString.append(pa.key)
                paraString.append("=")
                paraString.append("\(pa.value)")
                index+=1
                if (index == para.count){
                    break
                }
                paraString.append("&")
            }
        }
        return paraString
    }
    
    // (Data?, URLResponse?, Error?) -> Swift.Void
    func completeHanle(data: Data?, response: URLResponse?, error: Error?, uploadTask: URLSessionUploadTask? ,handle: FMNetCompleteHandle) -> Void {
        let complete: FMNetCompleteValue
        if error != nil {
            let serror = FMNetError.systemError(error!)
            complete = FMNetCompleteValue.failure(serror,nil)
            handle(complete)
            self.removeUploadTask(task: uploadTask)
            return
        }
        
        guard let obj = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments) else {
            let error = FMNetError.customError("没有响应数据或者解析错误")
            complete = FMNetCompleteValue.failure(error,nil)
            handle(complete)
            self.removeUploadTask(task: uploadTask)
            return
        }
        complete = FMNetCompleteValue.success(obj,nil)
        handle(complete)
        self.removeUploadTask(task: uploadTask)
    }
    
    func removeUploadTask(task: URLSessionUploadTask?) -> Void {
        if task != nil {
            self.uploadindItems.removeValue(forKey: task!)
        }
    }
    
    // 懒加载网络会话
    lazy var net_session: URLSession = {
        let con = URLSessionConfiguration.default
        con.timeoutIntervalForRequest = self.timeOut()
        let queue = OperationQueue()
        let sess: URLSession = URLSession(configuration: con, delegate: self, delegateQueue: queue)
        return sess
    }()
    
    // 下载的任务监听回调的字典集合
    lazy var dowmloadindItems: [URLSessionDownloadTask: FMNetDownload] = {
        return [URLSessionDownloadTask: FMNetDownload]()
    }()
    
    // 上传的任务监听回调字典集合
    lazy var uploadindItems: [URLSessionDataTask: FMNetUpload] = {
        return [URLSessionDataTask: FMNetUpload]()
    }()
}

extension FMNetManager: URLSessionDownloadDelegate{
    
    // MARK -- 下载完成回调
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL){
        guard let download = self.dowmloadindItems[downloadTask] else {
            return
        }
        let data = try? Data(contentsOf: location)
        let success = FileManager.default.createFile(atPath: download.filePath, contents: data, attributes: nil)
        
        let resultValue: FMNetCompleteValue
        if success {
           resultValue = FMNetCompleteValue.success(download.filePath,download.identify)
        } else {
            let error = FMNetError.customError("下载文件失败, 请检查路劲是否正确")
            resultValue = FMNetCompleteValue.failure(error,download.identify)
        }
        download.completeHandle(resultValue)
        self.dowmloadindItems.removeValue(forKey: downloadTask)
    }
    
    // MARK -- 下载进度回调
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64){
        
        guard let download = self.dowmloadindItems[downloadTask] else {
            return
        }
        
        let progress = Double(totalBytesWritten) / (Double)(totalBytesExpectedToWrite)
        
        DispatchQueue.main.async {
            download.progressBlock(Float(progress))
        }
    }
    
    // MARK -- 上传进度回调
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard let uploadTask = task as? URLSessionUploadTask else {
            return
        }
        guard let upload = self.uploadindItems[uploadTask] else {
            return
        }
        let progress = Double(totalBytesSent) / (Double)(totalBytesExpectedToSend)
        DispatchQueue.main.async {
            upload.progressBlock(Float(progress))
        }
    }
    
}

extension FMNetManager {
    // MARK -- 获取上传的request 以及  data
    func uploadRequest(url: String, fileData: Data) -> (uploadRequest: URLRequest, bodyData: Data) {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        
        
        let boundary = "FMNetManager.boundary"
        let content = "multipart/form-data; boundary=\(boundary)"
        request.setValue(content, forHTTPHeaderField: "Content-Type")
        
        var bodyStr = ""
        bodyStr.append("--\(boundary)\r\n")
        
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let name = dateFormatter.string(from: date)
        
        bodyStr.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(name)\"\r\n")
        bodyStr.append("Content-Type: application/octet-stream\r\n\r\n")
        
        let endStr = "\r\n--\(boundary)--"
        
        var data = Data()
        
        data.append(bodyStr.data(using: .utf8)!)
        data.append(fileData)
        data.append(endStr.data(using: .utf8)!)
        
        return (request, data)
    }
}
