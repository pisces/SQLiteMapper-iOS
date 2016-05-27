//
//  NSBundle+SQLiteMapper.swift
//  Pods
//
//  Created by Steve Kim on 5/26/16.
//
//

import Foundation
import UIKit

extension NSBundle {
    public func propertyList(plistName aPlistName: String!) -> AnyObject? {
        var path: String? = self.pathForResource(aPlistName, ofType: "plist")
        
        if path == nil {
            path = aPlistName + ".plist"
        }
        
        if let data = NSFileManager.defaultManager().contentsAtPath(path!) {
            if let result = try? NSPropertyListSerialization.propertyListWithData(data, options: NSPropertyListReadOptions.Immutable, format: nil) {
                return result
            }
        }
        
        return nil
    }
}