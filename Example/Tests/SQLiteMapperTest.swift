//
//  SQLiteMapperTest.swift
//  SQLiteMapper
//
//  Created by Steve Kim on 5/26/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit
import XCTest
import PSFoundation
import SQLiteMapper

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
        XCTAssertEqual("INSERT developer(name, age) VALUES(\"a\", \"21\")",
                       SQLiteMapper.sharedMapper().makeQuery("INSERT developer(name, age) VALUES({name}, {age})", param: ["name": "a", "age": 21]))
    }
    
    func testInsert() {
        let result: Bool = SQLiteMapper
            .sharedMapper()
            .update("ex1",
                    mapName: "ex1-sqlmap1",
                    sqlId: "insert-developer",
                    param: ["name": "b", "age": 21])
        
        XCTAssertTrue(result)
    }
    
    func testInsertMultiple() {
        let result: Bool = SQLiteMapper
            .sharedMapper()
            .update("ex1",
                    mapName: "ex1-sqlmap1",
                    sqlId: "insert-multiple",
                    param: ["name1": "steve",
                        "age1": 21,
                        "name2": "kim",
                        "age2": 25,
                        "name3": "sk",
                        "age3": 37])
        
        XCTAssertTrue(result)
    }
    
    func testSelectList() {
        let developers: [Developer]? = SQLiteMapper
            .sharedMapper().select("ex1",
                                   mapName: "ex1-sqlmap1",
                                   sqlId: "select")
        
        XCTAssertNotNil(developers)
        XCTAssertTrue(developers?.count > 0)
    }
    
    func testSelectOne() {
        let developer: Developer? = SQLiteMapper
            .sharedMapper().select("ex1",
                                   mapName: "ex1-sqlmap1",
                                   sqlId: "select-developer",
                                   param: ["name": "steve"])
        
        XCTAssertNotNil(developer!)
        XCTAssertEqual(21, developer!.age)
        XCTAssertEqual("steve", developer!.name)
    }
    
    func testDelete() {
        let result: Bool = SQLiteMapper.sharedMapper().update("ex1", mapName: "ex1-sqlmap1", sqlId: "delete")
        XCTAssertTrue(result)
    }
}
