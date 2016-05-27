//
//  DBModelTest.swift
//  SQLiteMapper
//
//  Created by Steve Kim on 5/27/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit
import XCTest
import PSFoundation
import SQLiteMapper

class DBModelTest: XCTestCase {
    let rawDict: NSDictionary = ["dbName": "ex1",
                                 "dbFilePath": "ex1.db",
                                 "sqlmaps": ["sqlmap1": "ex1-sqlmap1", "sqlmap2": "ex1-sqlmap2"]]
    
    override func setUp() {
        super.setUp()
        
        SQLiteMapper.sharedMapper().setUp(plistName: "sqlitemap-config", bundle: NSBundle(forClass: self.dynamicType))
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testSetProperties() {
        let model = DBModel(object: rawDict)
        
        XCTAssertEqual("ex1", model.dbName)
        XCTAssertEqual("ex1.db", model.dbFilePath)
        XCTAssertNotNil(model.sqlmaps)
        XCTAssertTrue(model.sqlmaps?.count > 0)
        XCTAssertEqual("INSERT INTO developer(name, age) VALUES({name1}, {age1})", model.queries("sqlmap1", sqlId: "insert-multiple")?.first)
        XCTAssertEqual("INSERT INTO developer(name, age) VALUES({name2}, {age2})", model.queries("sqlmap1", sqlId: "insert-multiple")?[1])
        XCTAssertEqual("INSERT INTO developer(name, age) VALUES({name3}, {age3})", model.queries("sqlmap1", sqlId: "insert-multiple")?.last)
        XCTAssertEqual("SELECT * FROM developer", model.queries("sqlmap1", sqlId: "select")?.first)
    }
}