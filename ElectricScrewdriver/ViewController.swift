//
//  ViewController.swift
//  ElectricScrewdriver
//
//  Created by 莫名 on 2022/10/30.
//

import Cocoa

class ESClassNode {
    var className: String!
    var key: String!
    var map: [String : Any]!
    lazy var modelContainerMapping = [String : String]()
    
    init(className: String!, key: String!, map: [String : Any]!) {
        self.className = className
        self.key = key
        self.map = map
    }
}

extension String {
    var upperFirstLetter: String {
        return String(self.prefix(1).capitalized + self.dropFirst())
    }
}

class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let jsonString = """
        {
            "api": "mtop.wdk.render.customer.hall",
            "data": {
                "hasMore": "false",
                "model": {
                    "isBackup": "false",
                    "isVIP": "1",
                    "linkUrl": "https://ai.alimebot.taobao.com/intl/index.htm?from=JrvZjDNNae&attemptquery=attemptquery",
                    "orgCode": "0571",
                    "abc": 123.3,
                    "orgName": "浙江子公司"
                },
                "relatedToSelection": "false",
                "successAndHasData": "true"
            },
            "list": [
                {
                    "a": 1,
                    "b": "123"
                }
            ],
            "list1": [
                {
                    "a": 1,
                    "b": "123"
                }
            ],
            "ret": [
                "SUCCESS::调用成功"
            ],
            "v": "1.0"
        }
        """

        guard let data = jsonString.data(using: String.Encoding.utf8) else {
            return
        }
        guard let dict = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers) as? [String : Any] else {
            return
        }

        handle(dict)
    }

    private func handle(_ map: [String : Any]) {
        let node = ESClassNode(className: "root", key: "root", map: map)
        var classList = [node]
        parserClassNode(node, &classList)
        
        var interfaces = [String]()
        var implementations = [String]()
        for node in classList {
            let result = classNode2Property(node)
            interfaces.append(result.0)
            implementations.append(result.1)
        }
        print(interfaces.joined(separator: "\n"))
        print(implementations.joined(separator: "\n"))
    }
    
    private func parserClassNode(_ node: ESClassNode, _ classList: inout [ESClassNode]) {
        for (key, value) in node.map {
            if let map = value as? [String : Any] {
                let className = "HM\(key.capitalized)Model"
                let classNode = ESClassNode(className: className, key: key, map: map)
                classList.append(classNode)
                parserClassNode(classNode, &classList)
            } else if let array = value as? [Any] {
                if let firstObject = findFirstObject(array) {
                    let className = "HM\(key.capitalized)Model"
                    let classNode = ESClassNode(className: className, key: key, map: firstObject)
                    classList.append(classNode)
                    
                    node.modelContainerMapping[key] = className
                    print(node.modelContainerMapping)
                    parserClassNode(classNode, &classList)
                }
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
        interface.append("@interface \(node.className!) : NSObject")
        for (key, value) in node.map {
            var type = "NSString"
            var qualifier = "copy"
            var isObj = "*"
            var propertyProtocol = ""
            if let clsName = node.modelContainerMapping[key] {
                propertyProtocol = "<\(clsName) *>"
            }
            
            if value is [Any] {
                type = "NSArray"
                qualifier = "strong"
            } else if value is [String : Any] {
                type = "HM\(key.capitalized)Model"
                qualifier = "strong"
            } else if value is String {
                let valueString = value as! String
                if ((key.hasPrefix("is") || key.hasPrefix("if")) && (valueString == "0" || valueString == "1")) ||
                    (valueString == "true" || valueString == "false") {
                    type = "BOOL"
                    qualifier = "assign"
                    isObj = ""
                }
            } else if value is Int {
                type = "NSInteger"
                qualifier = "assign"
                isObj = ""
            } else if value is Float {
                type = "CGFloat"
                qualifier = "assign"
                isObj = ""
            }
            
            let property = "@property (nonatomic, \(qualifier)) \(type)\(propertyProtocol) \(isObj)\(key);"
            interface.append(property)
        }
        interface.append("@end\n")
        
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
        }
        implementation.append("@end\n")
        
        return (interface.joined(separator: "\n"), implementation.joined(separator: "\n"))
    }

}

