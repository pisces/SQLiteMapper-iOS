//
//  SQLiteMapperTest.swift
//  SQLiteMapper
//
//  Created by Steve Kim on 5/26/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import XCTest
import PSFoundation
@testable import SQLiteMapper

class SQLiteMapperTest: XCTestCase {
    
    class Developer: AbstractJSONModel {
        var developer_id: Int = 0
        var name: String?
        var age: Int = 0
    }
    
    override func setUp() {
        super.setUp()
        
        SQLiteMapper.sharedMapper().setUp(plistName: "sqlitemap-config", bundle: NSBundle(forClass: self.dynamicType))
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testSharedMapper() {
        XCTAssertNotNil(SQLiteMapper.sharedMapper());
    }
    
    func testDBModel() {
        XCTAssertNotNil(SQLiteMapper.sharedMapper().dbModel(dbName: "ex1"))
    }
    
    func testMakeQuery() {
        XCTAssertEqual("INSERT developer(name, age) VALUES(\"a\", 21)",
                       SQLiteMapper.sharedMapper().makeQuery("INSERT developer(name, age) VALUES({name}, {age})", param: ["name": "a", "age": 21])!)
    }
    
    func testInsert() {
        let param = ["name": "b", "age": 21]
        
        SQLiteMapper.sharedMapper().update(
            "ex1",
            mapName: "ex1-sqlmap1",
            sqlId: "insert",
            param: param,
            completion: { (success, error, lastInsertRowId) in
                XCTAssertTrue(success)
                XCTAssertNil(error)
        })
    }
    
    func testInsertMultiple() {
        let param = ["name1": "steve",
                    "age1": 21,
                    "name2": "kim",
                    "age2": 25,
                    "name3": "sk",
                    "age3": 37]
        
        SQLiteMapper.sharedMapper().update(
            "ex1",
            mapName: "ex1-sqlmap1",
            sqlId: "insert-multiple", param: param,
            completion: { (success, error, lastInsertRowId) in
                XCTAssertTrue(success)
                XCTAssertNil(error)
        })
    }
    
    func testSelectList() {
        SQLiteMapper.sharedMapper().select("ex1", mapName: "ex1-sqlmap1", sqlId: "select") { (result: [Developer]?, error) in
            
            XCTAssertNotNil(result)
            XCTAssertTrue(result?.count > 0)
        }
    }
    
    func testSelectOne() {
        SQLiteMapper.sharedMapper().select(
            "ex1",
            mapName: "ex1-sqlmap1",
            sqlId: "select-developer",
            param: ["name": "steve"]) { (result: Developer?, error) in
                XCTAssertNotNil(result)
                
                if let result = result {
                    XCTAssertEqual(21, result.age)
                    XCTAssertEqual("steve", result.name)
                }
        }
    }
    
    func testDelete() {
        SQLiteMapper.sharedMapper().update(
            "ex1",
            mapName: "ex1-sqlmap1",
            sqlId: "delete") { (success, error, lastInsertRowId) in
                XCTAssertTrue(success)
                XCTAssertNil(error)
        }
    }
}
