//
//  SQLiteMapper.swift
//  SQLiteMapper
//
//  Created by Steve Kim on 5/26/16.
//
//

import UIKit
import FMDB
import PSFoundation

public class SQLiteMapper: NSObject {
    private let dbModelDict: NSMutableDictionary = NSMutableDictionary()
    private let queue: dispatch_queue_t = dispatch_queue_create("SQLiteMapperQueue", DISPATCH_QUEUE_SERIAL)
    
    public private(set) var bundle: NSBundle?
    
    // ================================================================================================
    //  Public
    // ================================================================================================
    
    static public func sharedMapper() -> SQLiteMapper {
        struct Static {
            static var onceToken: dispatch_once_t = 0
            static var instance: SQLiteMapper? = nil
        }
        dispatch_once(&Static.onceToken) {
            Static.instance = SQLiteMapper()
        }
        return Static.instance!
    }
    
    public func dbModel(dbName aName: String!) -> DBModel? {
        return dbModelDict[aName] as? DBModel
    }
    
    public func makeQuery(raw: String!, param: NSDictionary?) -> String? {
        if param == nil {
            return raw
        }
        
        var result: String = raw
        var range: NSRange
        
        for (key, value) in param! {
            range = NSMakeRange(0, result.characters.count)
            
            let queryRegex = try? NSRegularExpression(pattern: "@(.*|)\\{" + (key as! String) + "\\}", options: [.CaseInsensitive])
            
            if (queryRegex?.matchesInString(result, options: [], range: range).count > 0) {
                result = (queryRegex?.stringByReplacingMatchesInString(result, options: NSMatchingOptions.ReportCompletion, range: range, withTemplate: String(value)))!
            } else {
                let regex = try? NSRegularExpression(pattern: "\\{" + (key as! String) + "\\}", options: [.CaseInsensitive])
                
                if (regex?.matchesInString(result, options: [], range: range).count > 0) {
                    result = (regex?.stringByReplacingMatchesInString(result, options: NSMatchingOptions.ReportCompletion, range: range, withTemplate: "\"" + String(value) + "\""))!
                }
            }
        }
        
        return result
    }
    
    public func select<T: AbstractJSONModel>(dbName: String!, mapName: String!, sqlId: String!) -> T? {
        return select(dbName, mapName: mapName, sqlId: sqlId, param: nil)
    }
    
    public func select<T: AbstractJSONModel>(dbName: String!, mapName: String!, sqlId: String!, param: NSDictionary?) -> T? {
        var item: T?
        
        dispatch_sync(queue) {
            do {
                let (result, db) = try self.select(dbName, mapName: mapName, sqlId: sqlId, param: param)
                
                if result != nil && result!.next() == true {
                    item = T(object: result!.resultDictionary()!)
                    
                    print("dict ->", result!.resultDictionary()!, item!.dictionary)
                }
                
                db?.close()
            } catch let error as NSError {
                print("error ->", error)
            }
        }
        
        return item
    }
    
    public func select<T: AbstractJSONModel>(dbName: String!, mapName: String!, sqlId: String!) -> [T]? {
        return select(dbName, mapName: mapName, sqlId: sqlId, param: nil)
    }
    
    public func select<T: AbstractJSONModel>(dbName: String!, mapName: String!, sqlId: String!, param: NSDictionary?) -> [T]? {
        var array: [T] = []
        
        dispatch_sync(queue) {
            do {
                let (result, db) = try self.select(dbName, mapName: mapName, sqlId: sqlId, param: param)
                
                while result?.next() == true {
                    
                    print("result?.resultDictionary() ->", result?.resultDictionary())
                    
                    array.append(T(object: result?.resultDictionary()!))
                }
                
                db?.close()
            } catch let error as NSError {
                print("error ->", error)
            }
        }
        
        return array
    }
    
    public func setUp(plistName aPlistName: String!, bundle: NSBundle!) {
        dispatch_sync(queue) {
            self.bundle = bundle;
            if let dbs = bundle.propertyList(plistName: aPlistName) as? Array<NSDictionary> {
                
                for db in dbs {
                    let model: DBModel = DBModel(object: db)
                    self.dbModelDict[model.dbName!] = model
                }
            }
        }
    }
    
    public func update(dbName: String!, mapName: String!, sqlId: String!) -> Bool {
        return update(dbName, mapName: mapName, sqlId: sqlId, param: nil)
    }
    
    public func update(dbName: String!, mapName: String!, sqlId: String!, param: NSDictionary?) -> Bool {
        var success: Bool = true
        
        dispatch_sync(queue) {
            var db: FMDatabase?
            
            do {
                if let dbModel = self.dbModel(dbName: dbName) {
                    if let queries = dbModel.queries(mapName, sqlId: sqlId) {
                        db = try self.getCurrentDB(dbModel)
                        
                        db!.beginTransaction()
                        
                        for query in queries {
                            let query = self.makeQuery(query, param: param)!
                            let pattern = try NSRegularExpression(pattern: "^(delete|DELETE|insert|INSERT|update|UPDATE)\\s", options: [.CaseInsensitive])
                            
                            if self.matchesPattern(pattern, inString: query) {
                                if !(try db!.executeUpdate(query, withParameterDictionary: nil)) {
                                    success = false
                                    db!.rollback()
                                    db!.close()
                                    return
                                }
                            }
                        }
                        
                        db!.commit()
                        db!.close()
                    }
                }
            } catch let error as NSError {
                success = false
                db?.rollback()
                db?.close()
                print("error ->", error)
            }
        }
        
        return success
    }
    
    // ================================================================================================
    //  Private
    // ================================================================================================
    
    private func select(dbName: String!, mapName: String!, sqlId: String!, param: NSDictionary?) throws -> (FMResultSet?, FMDatabase?) {
        if let dbModel = self.dbModel(dbName: dbName) {
            if let queries = dbModel.queries(mapName, sqlId: sqlId) {
                if let query = self.makeQuery(queries.first, param: param) {
                    let pattern = try NSRegularExpression(pattern: "^(select|SELECT)\\s", options: [.CaseInsensitive])
                    
                    if self.matchesPattern(pattern, inString: query) {
                        if let db = try getCurrentDB(dbModel) {
                            return (try db.executeQuery(query, values: nil), db)
                        }
                    }
                }
            }
        }
        
        return (nil, nil)
    }
    
    private func getCurrentDB(dbModel: DBModel) throws -> FMDatabase? {
        let dstPath = "\(NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first!)/\(dbModel.dbFilePath!)"
        
        if !NSFileManager.defaultManager().fileExistsAtPath(dstPath) {
            let srcPath: String = (bundle?.pathForResource(dbModel.dbFilePath!, ofType: nil)!)!
            
            try NSFileManager.defaultManager().copyItemAtURL(NSURL(fileURLWithPath: srcPath), toURL: NSURL(fileURLWithPath: dstPath))
        }
        
        if let db = FMDatabase(path: dstPath) {
            db.open()
            return db
        }
        
        return nil
    }
    
    private func matchesPattern(regex: NSRegularExpression!, inString: String!) -> Bool {
        return regex.matchesInString(inString, options: .ReportCompletion, range: NSMakeRange(0, inString.characters.count)).count > 0
    }
}