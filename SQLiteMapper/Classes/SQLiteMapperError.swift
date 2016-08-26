//
//  SQLiteMapperError.swift
//  Pods
//
//  Created by Steve Kim on 8/26/16.
//
//

import Foundation

public enum SQLiteMapperErrorCode: Int {
    case Unknown = 1
    case DoeseNotExistSqlId = 2
    case DoeseNotExistDbName = 3
    case InvalidSqlQuery = 4
}

public enum SQLiteMapperErrorType: ErrorType {
    case Unknown
    case DoeseNotExistSqlId(sqlId: String)
    case DoeseNotExistDbName(dbName: String)
    case InvalidSqlQuery(query: String)
}

public class SQLiteMapperError: NSError {
}