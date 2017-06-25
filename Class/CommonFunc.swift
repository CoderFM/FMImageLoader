//
//  CommonFunc.swift
//  SwiftSQLite
//
//  Created by 周发明 on 17/6/19.
//  Copyright © 2017年 周发明. All rights reserved.
//

import Foundation

extension String{
    public var fm_md5: String{
        get{
            let str = self.cString(using: String.Encoding.utf8)
            let strLen = CC_LONG(self.lengthOfBytes(using: String.Encoding.utf8))
            let digestLen = Int(CC_MD5_DIGEST_LENGTH)
            let result = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: digestLen)
            CC_MD5(str!, strLen, result)
            let hash = NSMutableString()
            for i in 0..<digestLen {
                hash.appendFormat("%02x", result[i])
            }
            result.deallocate(capacity: digestLen)
            return hash as String
        }
    }
}
