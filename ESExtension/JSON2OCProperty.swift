//
//  JSON2OCProperty.swift
//  ESExtension
//
//  Created by 莫名 on 2022/11/1.
//

import Foundation
import XcodeKit

class ESClassNode {
    var className: String?
    var map: [String : Any]!
    var prefix: String!
    lazy var references = [String]()
    lazy var keyModelMapping = [String : String]()
    lazy var modelContainerMapping = [String : String]()
    
    init(className: String?, prefix: String!, map: [String : Any]!) {
        self.className = className
        self.prefix = prefix
        self.map = map
    }
}

extension String {
    var upperFirstLetter: String {
        return String(self.prefix(1).capitalized + self.dropFirst())
    }
}

//MARK: JSON To OC Property Extension

extension SourceEditorCommand {
    
    func handleJSON2OCProperty(with invocation: XCSourceEditorCommandInvocation) {
        let contentUTI = invocation.buffer.contentUTI
        // 判断是否为OC .h或.m文件，否则不处理
        if contentUTI != "public.c-header" && contentUTI != "public.objective-c-source" {
            return
        }
        let buffer = invocation.buffer
        guard let startLine = (buffer.selections.firstObject as? XCSourceTextRange)?.start.line else {
            return
        }
        guard let endLine = (buffer.selections.lastObject as? XCSourceTextRange)?.end.line else {
            return
        }
        guard let lines = buffer.lines as? Array<String> else {
            return
        }
        
        var jsonString = ""
        for i in startLine...endLine {
            if 0 <= i && i < lines.count {
                jsonString += lines[i]
            }
        }
        
        if jsonString.count == 0 {
            return
        }
        
        guard let data = jsonString.data(using: String.Encoding.utf8) else {
            return
        }
        guard let map = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers) as? [String : Any] else {
            return
        }
        
        let className = (map["$class"] as? String) ?? "<#className#>"
        let prefix = (map["$prefix"] as? String) ?? "HM"
        let rootNode = ESClassNode(className: className, prefix: prefix, map: map)
        var classList = [rootNode]
        parserClassNode(rootNode, &classList)
        
        var statementSet = Set<String>()
        var interfaces = [String]()
        var implementations = [String]()
        for node in classList {
            for className in node.references {
                if className != node.className {
                    statementSet.insert("@class \(className);");
                }
            }
            
            let result = classNode2Property(node)
            interfaces.append(result.0)
            implementations.append(result.1)
        }
        
        let interfaceContent = interfaces.joined(separator: "\n")
        let implCotnent = implementations.joined(separator: "\n")
        let finalContent = interfaceContent + "\n" + implCotnent
        buffer.lines.insert(finalContent, at: endLine + 1)
        buffer.lines.removeObjects(in: NSMakeRange(startLine, endLine - startLine + 1))
        
        let statementContent = statementSet.joined(separator: "\n")
        var findInsertIndex = 0;
        for (i, line) in buffer.lines.enumerated() {
            if (line as! String).hasPrefix("@interface") {
                findInsertIndex = i
                break
            }
        }
        buffer.lines.insert(statementContent, at: findInsertIndex)
    }
    
}

extension SourceEditorCommand {
    
    private func parserClassNode(_ node: ESClassNode, _ classList: inout [ESClassNode]) {
        for (key, value) in node.map {
            if let valueString = value as? String {
                var className: String? = nil
                if valueString.hasPrefix("$[]") {
                    let formIndex = valueString.index(valueString.startIndex, offsetBy: 3)
                    className = String(valueString.suffix(from: formIndex))
                    node.modelContainerMapping[key] = className
                } else if valueString.hasPrefix("$") {
                    className = String(valueString.suffix(from: valueString.index(after: valueString.startIndex)))
                }
                if let _ = className {
                    node.references.append(className!)
                    continue
                }
            }
            
            if let map = value as? [String : Any], map.keys.count > 0 {
                let prefix = (map["$prefix"] as? String) ?? node.prefix
                let className = (map["$class"] as? String) ?? "\(prefix!)\(key.upperFirstLetter)Model"
                let classNode = ESClassNode(className: className, prefix: prefix, map: map)
                classList.append(classNode)
                
                node.references.append(className)
                node.keyModelMapping[key] = className
                parserClassNode(classNode, &classList)
            } else if let array = value as? [Any], let map = findFirstObject(array), map.keys.count > 0 {
                let prefix = (map["$prefix"] as? String) ?? node.prefix
                let className = (map["$class"] as? String) ?? "\(prefix!)\(key.upperFirstLetter)Model"
                let classNode = ESClassNode(className: className, prefix: prefix, map: map)
                classList.append(classNode)
                
                node.references.append(className)
                node.modelContainerMapping[key] = className
                parserClassNode(classNode, &classList)
            }
        }
    }
    
    private func findFirstObject(_ array: [Any]) -> [String : Any]? {
        guard let item = array.first else { return nil }
        
        if let map = item as? [String : Any] {
            return map
        } else if let array = item as? [Any] {
            return findFirstObject(array)
        }
        return nil
    }
    
    private func classNode2Property(_ node: ESClassNode) -> (String, String) {
        var interface = [String]()
        if let _ = node.className {
            interface.append("@interface \(node.className!) : NSObject")
        }
        for (key, value) in node.map {
            var type = "NSString"
            var qualifier = "copy"
            var pointer = "*"
            var propertyProtocol = ""
            
            let ignoreKeys = ["$class", "$prefix"]
            if ignoreKeys.contains(key) {
                continue
            }
            
            if let clsName = node.modelContainerMapping[key] {
                propertyProtocol = "<\(clsName) *>"
            }
            
            if let valueString = value as? String {
                if ((key.hasPrefix("is") || key.hasPrefix("if")) && (valueString == "0" || valueString == "1")) ||
                    (valueString == "true" || valueString == "false") {
                    type = "BOOL"
                    qualifier = "assign"
                    pointer = ""
                } else if valueString.hasPrefix("$[]") {
                    type = "NSArray"
                    qualifier = "strong"
                } else if valueString.hasPrefix("$") {
                    type = String(valueString.suffix(from: valueString.index(after: valueString.startIndex)))
                    qualifier = "strong"
                }
            } else if value is [Any] {
                type = "NSArray"
                qualifier = "strong"
            } else if value is [String : Any] {
                let map = value as! [String : Any]
                if map.keys.count > 0 {
                    type = "\(node.prefix!)\(key.upperFirstLetter)Model"
                } else {
                    type = "NSDictionary"
                }
                qualifier = "strong"
            } else if value is Int {
                type = "NSInteger"
                qualifier = "assign"
                pointer = ""
            } else if value is Float {
                type = "CGFloat"
                qualifier = "assign"
                pointer = ""
            }
            
            type = node.keyModelMapping[key] ?? type
            let property = "@property (nonatomic, \(qualifier)) \(type)\(propertyProtocol) \(pointer)\(key);"
            interface.append(property)
        }
        if let _ = node.className {
            interface.append("@end\n")
        }
        
        var implementation = [String]()
        implementation.append("@implementation \(node.className!)")
        var mappings = [String]()
        for (key, value) in node.modelContainerMapping {
            mappings.append("@\"\(key)\" : [\(value) class]")
        }
        if mappings.count > 0 {
            let mappingGetter = """
            
            + (NSDictionary *)modelContainerPropertyGenericClass {
                return @{
                    \(mappings.joined(separator: ",\n\t\t"))
                };
            }
            
            """
            implementation.append(mappingGetter)
        } else {
            implementation.append("")
        }
        implementation.append("@end\n")
        
        return (interface.joined(separator: "\n"), implementation.joined(separator: "\n"))
    }
    
}
