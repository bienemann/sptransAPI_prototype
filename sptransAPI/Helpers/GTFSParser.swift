//
//  GTFSParser.swift
//  sptransAPI
//
//  Created by resource on 8/2/16.
//  Copyright © 2016 bienemann. All rights reserved.
//

import Foundation
import Alamofire
import RealmSwift
import CSVImporter

class GTFSParser : NSObject, CSVParserDelegate{
    
//    static let sharedInstance = GTFSParser()
    
    func parseWithCheese(filePath: String, processValues: (structure: [String], line: [AnyObject]) -> Object?){
        let parser = CSVParser(path: filePath, delegate: self)
        parser.indexed = true
        parser.converterClosure = processValues
        parser.startReader()
    }
    
    func parseFromURL(urlString : String, completion: Array<Dictionary<String, AnyObject>> -> Void){
        Alamofire.request(.GET, urlString).responseData { (response) in
            self.GTFSFileToArray(response.data!, completion: { (dataArray) in
                if dataArray != nil{
                    completion(dataArray!)
                }else{
                    //to-do: tratar erro
                }
            })
        }
    }
    
    func parserDidStartDocument(parser: CSVParser) {
        
    }
    
    func parserDidEndDocument(parser: CSVParser) {
        
    }
    
    func parserDidReadLine<T : CollectionType>(parser: CSVParser, line: T) {
//        print(line)
    }
    
    
    func parseCSV(filePath : String, completion: (Array<Dictionary<String, String>>?) -> Void){
        
        let importer = CSVImporter<[String: String]>(path: filePath)
        importer.startImportingRecords(structure: { (headerValues) -> Void in }) { $0 }
            .onFail({
                print("failed to import records")
        }).onFinish { importedRecords in
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), { 
                var newRecordsArray : Array<Dictionary<String, String>> = Array()
                for record in importedRecords {
                    autoreleasepool({
                        var newDictionary : Dictionary<String, String> = Dictionary()
                        for (key, value) in record {
                            
                            autoreleasepool({
                            
                                var newKey = key.stringByReplacingOccurrencesOfString("\"", withString: "")
                                newKey = newKey.stringByTrimmingCharactersInSet(.newlineCharacterSet())
                                
                                var newValue = value.stringByReplacingOccurrencesOfString("\"", withString: "")
                                newValue = newValue.stringByTrimmingCharactersInSet(.newlineCharacterSet())
                                
                                newDictionary.updateValue(newValue, forKey: newKey)
                            })
                        }
                        newRecordsArray.append(newDictionary)
                    })
                }
                dispatch_async(dispatch_get_main_queue(), { 
                    completion(newRecordsArray)
                })
            })

        }

    }
    
    func GTFSFileToArray(data: NSData, completion: (Array<Dictionary<String, AnyObject>>?) -> Void){
        //Start parsing in a background thread
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            
            //return nil if we can't get a UTF-8 string from the data
            guard let dataString = NSString(data: data, encoding: NSUTF8StringEncoding) else {
                dispatch_async(dispatch_get_main_queue(), { 
                    completion(nil)
                })
                return
            }
            
            //break file into lines
            var lines : Array<String> = dataString.componentsSeparatedByCharactersInSet(.newlineCharacterSet())
            lines = lines.filter { (line) -> Bool in
                //remove empty lines (generated by \n\r line breaks)
                return line.characters.count > 0
            }
            
            //separate and 'clean' first line for indexing values
            var indexLine : Array<String> = lines.first!.componentsSeparatedByString(",")
            for (index,component) in indexLine.enumerate() {
                indexLine[index] = component.stringByReplacingOccurrencesOfString("\"", withString: "")
            }
            lines.removeFirst()
            
            var parsedArray : Array<Dictionary<String, AnyObject>> = Array()
            
            //parse each line in a key/value dictionary
            for line in lines {
                let elements : Array<String> = line.componentsSeparatedByString(",")
                var lineDict : Dictionary<String, AnyObject> = Dictionary()
                
                for (index, var element) in elements.enumerate() {
                    element = element.stringByReplacingOccurrencesOfString("\"", withString: "")
                    lineDict.updateValue(element, forKey: indexLine[index])
                }
                
                parsedArray.append(lineDict)
            }
            
            completion(parsedArray)
        }
    }
    
    func parse<T:Object>(fileRepresentation : Array<Dictionary<String, String>>, className: T.Type){
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) { 
            let realm = try! Realm()
            for object in fileRepresentation{
                autoreleasepool({ 
                    let newEntry = className.init()
                    for (key, value) in object{
                        newEntry.setValue(value, forKey: key)
                    }
                    try! realm.write {
                        realm.add(newEntry)
                        print("realm addes entry:\n\(newEntry)\n")
                    }
                })
            }
        }
    }
    
    func parseLine<T:Object>(structure: Array<String>, line: Array<AnyObject>, model: T.Type) -> T?{
        
        if structure.count == line.count {
            let newEntry = model.init()
            for (index, key) in structure.enumerate(){
                newEntry.setValue(line[index], forKey: key)
            }
            return newEntry
        }
        
        print("problem creating realm object")
        return nil
    }
    
    
}
