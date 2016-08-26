//
//  DBModel.swift
//  Pods
//
//  Created by Steve Kim on 5/26/16.
//
//

import PSFoundation

public class DBModel: AbstractJSONModel {
    public private(set) var dbName: String?
    public private(set) var dbFilePath: String?
    public private(set) var sqlmaps: NSDictionary?
    
    let dbNameKey: String = "dbName"
    let dbFilePathKey: String = "dbFilePath"
    
    override public func setProperties(object: AnyObject!) {
        if let dict = object as? NSDictionary {
            self.dbName = dict[dbNameKey] as? String
            self.dbFilePath = dict[dbFilePathKey] as? String
            
            if let mapsDict = dict["sqlmaps"] as? NSDictionary {
                let mutableMaps: NSMutableDictionary = NSMutableDictionary()
                
                for (key, value) in mapsDict {
                    mutableMaps[key as! String] = SQLiteMapper.sharedMapper().bundle?.propertyList(plistName: value as! String)
                }
                
                self.sqlmaps = mutableMaps;
            }
        }
    }
    
    public func queries(mapName: String!, sqlId: String!) -> [String]? {
        let value: AnyObject? = sqlmaps?[mapName]?[sqlId]
        
        if value is NSString {
            return [value as! String]
        } else if value is NSArray {
            return value as? Array<String>
        }
        
        return nil
    }
}
