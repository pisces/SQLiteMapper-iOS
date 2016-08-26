//
//  SQLiteMapper.swift
//  SQLiteMapper
//
//  Created by Steve Kim on 5/26/16.
//
//

import FMDB
import PSFoundation

public class SQLiteMapper: NSObject {
    // MARK: - Constants
    
    private let dbModelDict: NSMutableDictionary = NSMutableDictionary()
    private let queue: dispatch_queue_t = dispatch_queue_create("SQLiteMapperQueue", DISPATCH_QUEUE_SERIAL)
    
    // MARK: - Properties
    
    public private(set) var bundle: NSBundle?
    
    // MARK: - Public methods
    
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
        var result: String = raw
            .stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        
        if param == nil {
            return result
        }
        
        var range: NSRange
        
        for (key, value) in param! {
            range = NSMakeRange(0, result.characters.count)
            let queryRegex = try? NSRegularExpression(pattern: "@(.*|)\\{" + (key as! String) + "\\}", options: [.CaseInsensitive])
            
            if (queryRegex?.matchesInString(result, options: [], range: range).count > 0) {
                result = (queryRegex?.stringByReplacingMatchesInString(result, options: NSMatchingOptions.ReportCompletion, range: range, withTemplate: String(value)))!
            } else {
                let regex = try? NSRegularExpression(pattern: "\\{" + (key as! String) + "\\}", options: [.CaseInsensitive])
                
                if (regex?.matchesInString(result, options: [], range: range).count > 0) {
                    let valueString = value is String ? "\"" + String(value) + "\"" : String(value)
                    
                    result = (regex?.stringByReplacingMatchesInString(result, options: NSMatchingOptions.ReportCompletion, range: range, withTemplate: valueString))!
                }
            }
        }
        
        range = NSMakeRange(0, result.characters.count)
        let regex = try? NSRegularExpression(pattern: "\\{(\\w+)\\}", options: [.CaseInsensitive])
        
        if (regex?.matchesInString(result, options: [], range: range).count > 0) {
            result = (regex?.stringByReplacingMatchesInString(result, options: NSMatchingOptions.ReportCompletion, range: range, withTemplate: "NULL"))!
        }
        
        return result
    }
    
    public func select<T: AbstractJSONModel>(
        dbName: String!,
        mapName: String!,
        sqlId: String!,
        param: NSDictionary? = nil,
        completion: (result: T?, error: NSError?) -> Void) {
        dispatch_sync(queue) {
            var item: T?
            
            do {
                let (result, db) = try self.select(dbName, mapName: mapName, sqlId: sqlId, param: param)
                
                if let result = result where result.next() {
                    item = T(object: result.resultDictionary()!)
                }
                
                db?.close()
                
                dispatch_async(dispatch_get_main_queue(), {
                    completion(result: item, error: nil)
                })
            } catch let error as NSError {
                self.makeError(error.domain, code: .Unknown, userInfo: error.userInfo, completion: { (err) in
                    completion(result: nil, error: err)
                })
            }
        }
    }
    
    public func select<T: AbstractJSONModel>(
        dbName: String!,
        mapName: String!,
        sqlId: String!,
        param: NSDictionary? = nil,
        completion: (result: [T]?, error: NSError?) -> Void) {
        
        dispatch_sync(queue) {
            var array: [T] = []
            
            func _error(domain: String!, code: SQLiteMapperErrorCode) {
                self.makeError(domain, code: code, completion: { (err) in
                    completion(result: nil, error: err)
                })
            }
            
            do {
                let (result, db) = try self.select(dbName, mapName: mapName, sqlId: sqlId, param: param)
                
                if let result = result {
                    while result.next() == true {
                        array.append(T(object: result.resultDictionary()!))
                    }
                }
                
                db?.close()
                
                dispatch_async(dispatch_get_main_queue(), {
                    completion(result: array, error: nil)
                })
            } catch SQLiteMapperErrorType.DoeseNotExistSqlId(let sqlId) {
                _error("sqlId \(sqlId) does not exist!", code: .DoeseNotExistSqlId)
            } catch SQLiteMapperErrorType.DoeseNotExistDbName(let dbName) {
                _error("dbName \(dbName) does not exist!", code: .DoeseNotExistDbName)
            } catch SQLiteMapperErrorType.InvalidSqlQuery(let query) {
                _error("Invalid query: \(query)", code: .InvalidSqlQuery)
            } catch let error as NSError {
                _error("\(error.domain)", code: .Unknown)
            }
        }
    }
    
    public func setUp(plistName aPlistName: String!, bundle: NSBundle? = nil) {
        dispatch_sync(queue) {
            guard let bundle = bundle else {return}
            
            self.bundle = bundle;
            
            if let dbs = bundle.propertyList(plistName: aPlistName) as? Array<NSDictionary> {
                
                for db in dbs {
                    let model: DBModel = DBModel(object: db)
                    self.dbModelDict[model.dbName!] = model
                }
            }
        }
    }
    
    public func update(
        dbName: String!,
        mapName: String!,
        sqlId: String!,
        param: NSDictionary? = nil,
        completion: ((success: Bool, error: SQLiteMapperError?, lastInsertRowId: Int) -> Void)? = nil) {
        dispatch_sync(queue) {
            var db: FMDatabase?
            
            func _completion(success: Bool, error: SQLiteMapperError? = nil, lastInsertRowId: Int) {
                if let completion = completion {
                    completion(success: success, error: error, lastInsertRowId: lastInsertRowId)
                }
            }
            
            func _error(domain: String!, code: SQLiteMapperErrorCode, userInfo: [NSObject: AnyObject]? = nil) {
                self.makeError(domain, code: code, completion: { (err) in
                    if let completion = completion {
                        completion(success: false, error: err, lastInsertRowId: 0)
                    }
                })
            }
            
            guard let dbModel = self.dbModel(dbName: dbName) else {
                _error("dbName \"\(dbName)\" does not exist!", code: .DoeseNotExistDbName)
                return
            }
            
            guard let queries = dbModel.queries(mapName, sqlId: sqlId) else {
                _error("sqlId \"\(sqlId)\" does not exist!", code: .DoeseNotExistSqlId)
                return
            }
            
            do {
                if let db = try self.getCurrentDB(dbModel) {
                    db.beginTransaction()
                    
                    for query in queries {
                        let query = self.makeQuery(query, param: param)!
                        let pattern = try NSRegularExpression(pattern: "^(delete|DELETE|insert|INSERT||update|UPDATE)(.*)", options: [.CaseInsensitive])
                        
                        if self.matchesPattern(pattern, inString: query) {
                            if !db.executeUpdate(query, withParameterDictionary: nil) {
                                db.rollback()
                                db.close()
                                _error("Invalid query: \(query)", code: .InvalidSqlQuery)
                                return
                            }
                        }
                    }
                    
                    db.commit()
                    
                    let lastInsertRowId: Int = Int(db.lastInsertRowId())
                    
                    db.close()
                    
                    dispatch_async(dispatch_get_main_queue(), {
                        _completion(true, lastInsertRowId: lastInsertRowId)
                    })
                }
            } catch let err as NSError {
                db?.rollback()
                db?.close()
                _error("\(err.domain)!", code: .Unknown)
            }
        }
    }
    
    // MARK: - Private methods
    
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
    
    private func makeError(
        domain: String!,
        code: SQLiteMapperErrorCode,
        userInfo: [NSObject: AnyObject]? = nil,
        completion: (error: SQLiteMapperError) -> Void) {
        dispatch_async(dispatch_get_main_queue(), {
            let error = SQLiteMapperError(domain: domain, code: code.rawValue, userInfo: userInfo)
            #if DEBUG
                print("\(self.dynamicType): Error -> \(error)")
            #endif
            completion(error: error)
        })
    }
    
    private func select(dbName: String!, mapName: String!, sqlId: String!, param: NSDictionary?) throws -> (FMResultSet?, FMDatabase?) {
        guard let dbModel = self.dbModel(dbName: dbName) else {
            throw SQLiteMapperErrorType.DoeseNotExistDbName(dbName: dbName)
        }
        
        guard let queries = dbModel.queries(mapName, sqlId: sqlId) else {
            throw SQLiteMapperErrorType.DoeseNotExistSqlId(sqlId: sqlId)
        }
        
        guard let query = self.makeQuery(queries.first, param: param) else {
            throw SQLiteMapperErrorType.InvalidSqlQuery(query: queries.first!)
        }
        
        let pattern = try NSRegularExpression(pattern: "^(select|SELECT)\\s", options: [.CaseInsensitive])
        
        if self.matchesPattern(pattern, inString: query) {
            if let db = try getCurrentDB(dbModel) {
                return (try db.executeQuery(query, values: nil), db)
            }
        }
        
        return (nil, nil)
    }
    
    private func matchesPattern(regex: NSRegularExpression!, inString: String!) -> Bool {
        return regex.matchesInString(inString, options: .ReportCompletion, range: NSMakeRange(0, inString.characters.count)).count > 0
    }
}