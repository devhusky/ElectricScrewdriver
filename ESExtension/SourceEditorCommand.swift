//
//  SourceEditorCommand.swift
//  ESExtension
//
//  Created by 莫名 on 2022/10/30.
//

import Foundation
import XcodeKit

class SourceEditorCommand: NSObject, XCSourceEditorCommand {
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        // Implement your command here, invoking the completion handler when done. Pass it nil on success, and an NSError on failure.
        if invocation.commandIdentifier.contains("GeneratePropertyGetter") {
            handleGeneratePropertyGetter(with: invocation)
        } else if invocation.commandIdentifier.contains("ImportHeader") {
            handleImportHeader(with: invocation)
        } else if invocation.commandIdentifier.contains("JSON2OCProperty") {
            handleJSON2OCProperty(with: invocation)
        }
        completionHandler(nil)
    }
    
}
