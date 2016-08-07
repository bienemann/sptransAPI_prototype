//
//  CSVParser.swift
//  CSV
//
//  Created by Allan Hoeltje on 8/3/16.
//  Copyright © 2016 Allan Hoeltje.
//
//	The algorithm employed here in the parse method was gleaned from libcsv by Robert Gamble.
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy of
//	this software and associated documentation files (the "Software"), to deal in
//	the Software without restriction, including without limitation the rights to
//	use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//	the Software, and to permit persons to whom the Software is furnished to do so,
//	subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in all
//	copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//	FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//	COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//	IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//	CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import Foundation
import RealmSwift

/// A class for handling comma-separated-values text files.
/// The value delimiter defaults to "," but can be any other character you like.


public class CSVParser: NSObject
{
    let csvFile: TextFile
    private var delim: UInt32
    private var delimiter: String
    private var quote: UInt32
    public var indexed: Bool = false
    public var header : [String] = []
    public var converterClosure : (([String], [AnyObject]) -> Object?)?
    
    /// The current line number being processed in the CSV file
    public var lineCount = 0
    
    enum ParserState
    {
        case ROW_NOT_BEGUN				//	There have not been any fields encountered for this row
        case FIELD_NOT_BEGUN			//	There have been fields but we are currently not in one
        case FIELD_BEGUN				//	We are in a field
        case FIELD_MIGHT_HAVE_ENDED		//	We encountered a double quote inside a quoted field
    }
    
    private var pstate		= ParserState.FIELD_NOT_BEGUN
    private var quoted		= false
    private var spaces		= 0
    private var entryPos	= 0
    
    private let csvTab: UInt32		= 0x09
    private let csvSpace: UInt32	= 0x20
    private let csvCR: UInt32		= 0x0d
    private let csvLF: UInt32		= 0x0a
    private let csvComma: UInt32	= 0x2c
    private let csvQuote: UInt32	= 0x22
    
    
    /// Initialize the CSV object with a file path.
    /// - Parameters:
    ///   - path: an input path for a CSV reader or an output path for a writer.
    ///   - delegate: the parser delegate object
    public init(path: String, delegate: CSVParserDelegate)
    {
        self.csvFile = TextFile(path: path)
        self.delegate = delegate
        
        self.delimiter = ""
        self.delim = 0
        self.quote = 0
    }
    
    
    /// delegate management. The delegate is not retained.
    weak public var delegate: CSVParserDelegate?
    
    
    /// A CSV reader.
    /// - Parameters:
    ///   - delimiter: optional delimeter character, defaults to ","
    ///   - quote: optional quote character, defaults to "\"".  A field in a CSV file that contains the delimiter character should be quoted.
    public func startReader(delimiter: String = ",", quote: String = "\"")
    {
        self.delimiter = delimiter
        self.delim	= (delimiter.unicodeScalars.first?.value)!
        self.quote	= (quote.unicodeScalars.first?.value)!
        
        lineCount = 0
        if let d = delegate
        {
            d.parserDidStartDocument(self)
            
            if let csvStreamReader = self.csvFile.reader()
            {
                var line = csvStreamReader.nextLine()
                
                let realm = try! Realm()
                realm.beginWrite()
                let startDate = NSDate()
                
                while line != nil
                {
                    autoreleasepool({ 
                        let parsedLine = parse(line!)
                        lineCount += 1
                        
                        if lineCount != 1{
                            if self.indexed {
                                if self.converterClosure != nil {
                                    if let entry = converterClosure!(self.header, parsedLine) {
                                        realm.add(entry)
                                    }else{
                                        
                                        //To-do: tratar erro
                                        
                                    }
                                }else{
                                    d.parserDidReadLine(self, line: zipToDict(self.header, values: parsedLine))
                                }
                            }
                        }else{
                            self.header = parsedLine
                        }
                        
                        d.parserDidReadLine(self, line: parsedLine)
                        line = csvStreamReader.nextLine()
                        
                        if lineCount % 10000 == 0 {
                            try! realm.commitWrite()
                            //                        print("committing objects; count: \(lineCount)")
                            realm.beginWrite()
                        }
                    })

                }
                
                try! realm.commitWrite()
                print("committing objects; count: \(lineCount)")
                let finishDate = NSDate()
                print(String(format: "time elapsed: %.2f seconds", finishDate.timeIntervalSinceDate(startDate)))
                csvStreamReader.close()
            }
            
            d.parserDidEndDocument(self)
        }
    }
    
    
    func zipToDict<
        S0 : SequenceType,
        S1 : SequenceType where
        S0.Generator.Element : Hashable
        >(keys: S0, values: S1) -> [String:AnyObject] {
        var dict: [String:AnyObject] = [:]
        for (key, value) in zip(keys, values) {
//            if (value as! String).characters.count > 0 {
//                if Int(value as! String) != nil {
//                    dict[(key as! String)] = (value as! Int)
//                }
//                dict[(key as! String)] = value as! String
//            }
            dict[(key as! String)] = value as? AnyObject
        }
        return dict
    }
    
    
    /// A CSV writer.
    /// - Parameters:
    ///   - delimiter: optional delimeter character, defaults to ","
    ///   - quote: optional quote character, defaults to "\"".  A field in a CSV file that contains the delimiter character should be quoted.
    public func writer(delimiter: String = ",", quote: String = "\"")
    {
        self.delimiter = delimiter
        self.delim	= (delimiter.unicodeScalars.first?.value)!
        self.quote	= (quote.unicodeScalars.first?.value)!
        
        //	TODO: CSV writer
    }
    
    //	used to time the TextFile reader without csv parsing getting in the way
    private func xparse(line: String) -> [String]
    {
        let components = [String]()
        return components
    }
    
    private func parse(line: String) -> [String]
    {
        //		print( "\n\(line)")
        
        var components = [String]()
        var field = ""
        
        entryPos	= 0
        quoted		= false
        spaces		= 0
        pstate		= .ROW_NOT_BEGUN
        
        for ch in line.unicodeScalars
        {
            let c = ch.value
            switch pstate
            {
            case .ROW_NOT_BEGUN:
                fallthrough
            case .FIELD_NOT_BEGUN:
                if ((c == csvSpace) || (c == csvTab)) && (c != delim)
                {
                    //	space or tab
                    //	continue
                }
                else
                    if c == delim
                    {
                        components.append(field)	//	SUBMIT_FIELD
                        field = ""
                        
                        entryPos	= 0
                        quoted		= false
                        spaces		= 0
                        pstate		= .FIELD_NOT_BEGUN
                    }
                    else
                        if c == quote
                        {
                            quoted = true
                            pstate = .FIELD_BEGUN
                        }
                        else
                        {
                            field.append(ch)			//	SUBMIT_CHAR
                            entryPos += 1
                            quoted = false
                            pstate = .FIELD_BEGUN
                }
                
            case .FIELD_BEGUN:
                if c == quote
                {
                    if quoted
                    {
                        field.append(ch)		//	SUBMIT_CHAR
                        entryPos += 1
                        pstate = .FIELD_MIGHT_HAVE_ENDED
                    }
                    else
                    {
                        //	double quote inside non-quoted field
                        //						if (p->options & CSV_STRICT)
                        //						{
                        //							p->status = CSV_EPARSE;
                        //							p->quoted = quoted, p->pstate = pstate, p->spaces = spaces, p->entry_pos = entry_pos;
                        //							return pos-1;
                        //						}
                        
                        field.append(ch)		//	SUBMIT_CHAR
                        entryPos += 1
                        spaces = 0
                    }
                }
                else
                    if c == delim
                    {
                        //	Delimiter
                        if quoted
                        {
                            field.append(ch)		//	SUBMIT_CHAR
                            entryPos += 1
                        }
                        else
                        {
                            components.append(field)	//	SUBMIT_FIELD
                            field = ""
                            
                            entryPos	= 0
                            quoted		= false
                            spaces		= 0
                            pstate		= .FIELD_NOT_BEGUN
                        }
                    }
                    else
                        if !quoted && ((c == csvSpace) || (c == csvTab))
                        {
                            //	Tab or space for non-quoted field
                            
                            field.append(ch)			//	SUBMIT_CHAR
                            entryPos += 1
                            spaces += 1
                        }
                        else
                        {
                            field.append(ch)			//	SUBMIT_CHAR
                            entryPos += 1
                            spaces = 0
                }
                
            case .FIELD_MIGHT_HAVE_ENDED:
                //	This only happens when a quote character is encountered in a quoted field
                if c == delim
                {
                    let range = field.endIndex.advancedBy(-(spaces + 1)) ..< field.endIndex
                    field.removeRange(range)
                    
                    entryPos -= (spaces + 1)	//	get rid of spaces and original quote
                    components.append(field)	//	SUBMIT_FIELD
                    field = ""
                    
                    entryPos	= 0
                    quoted		= false
                    spaces		= 0
                    pstate		= .FIELD_NOT_BEGUN
                }
                else
                    if (c == csvSpace) || (c == csvTab)
                    {
                        field.append(ch)			//	SUBMIT_CHAR
                        entryPos += 1
                        spaces += 1
                    }
                    else
                        if c == quote
                        {
                            if spaces > 0
                            {
                                //	STRICT ERROR - unescaped double quote
                                //						if (p->options & CSV_STRICT)
                                //						{
                                //							p->status = CSV_EPARSE;
                                //							p->quoted = quoted;
                                //							p->pstate = pstate;
                                //							p->spaces = spaces;
                                //							p->entry_pos = entry_pos;
                                //							return pos-1;
                                //						}
                                
                                field.append(ch)		//	SUBMIT_CHAR
                                entryPos += 1
                                spaces = 0
                            }
                            else
                            {
                                //	Two quotes in a row
                                pstate = .FIELD_BEGUN
                            }
                        }
                        else
                        {
                            //	Anything else
                            field.append(ch)			//	SUBMIT_CHAR
                            entryPos += 1
                            spaces = 0
                            pstate = .FIELD_BEGUN
                }
            }
        }
        
        if pstate == .FIELD_BEGUN
        {
            //	We still have an unfinished field
            components.append(field)
        }
        else
            if pstate == .FIELD_MIGHT_HAVE_ENDED
            {
                if !field.isEmpty
                {
                    let range = field.endIndex.advancedBy(-(spaces + 1)) ..< field.endIndex
                    field.removeRange(range)
                    components.append(field)
                }
        }
        
        return components
    }
}


/// CSVParser Delegate Protocol
public protocol CSVParserDelegate: NSObjectProtocol
{
    /// sent when the parser begins parsing the document.
    func parserDidStartDocument(parser: CSVParser)
    
    /// sent when the parser has completed parsing. If this is encountered, the parse was successful.
    func parserDidEndDocument(parser: CSVParser)
    
    /// sent to the delegate for each line in the CSV document
    /// - Parameters:
    ///   - parser: the CSVParser object
    ///   - line: an array of strings, one element for each delimited field in the line
    func parserDidReadLine<T:CollectionType>(parser: CSVParser, line: T)
}
