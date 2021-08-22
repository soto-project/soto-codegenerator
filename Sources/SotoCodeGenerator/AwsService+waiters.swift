//===----------------------------------------------------------------------===//
//
// This source file is part of the Soto for AWS open source project
//
// Copyright (c) 2017-2021 the Soto project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Soto project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import SotoSmithy

extension AwsService {
    /// Generate list of waiter contexts
    func generateWaiterContexts() throws -> [String: Any] {
        var context: [String: Any] = [:]
        context["name"] = self.serviceName
        var waiters: [WaiterContext] = []
        for operation in operations {
            guard let trait = operation.value.trait(type: WaitableTrait.self) else { continue }
            for waiter in trait.value {
                let waiterContext = try generateWaiterContext(
                    waiter.value,
                    name: waiter.key,
                    operation: operation.value,
                    operationName: operation.key
                )
                waiters.append(waiterContext)
            }
        }
        if waiters.count > 0 {
            context["waiters"] = waiters.sorted { $0.waiterName < $1.waiterName }
        }
        return context
    }

    /// Generate waiter context from waiter
    func generateWaiterContext(_ waiter: WaitableTrait.Waiter, name: String, operation: OperationShape, operationName: ShapeId) throws -> WaiterContext {
        var acceptorContexts: [AcceptorContext] = []
        for acceptor in waiter.acceptors {
            acceptorContexts.append(self.generateAcceptorContext(acceptor))
        }
        let operationContext = try self.generateOperationContext(operation, operationName: operationName, streaming: false)
        return .init(
            waiterName: name,
            operation: operationContext,
            inputKey: operationContext.inputShape,
            acceptors: acceptorContexts,
            minDelayTime: waiter.minDelay,
            maxDelayTime: waiter.maxDelay,
            deprecated: waiter.deprecated ?? false,
            comment: self.processDocs(waiter.documentation)
        )
    }

    /// Generate acceptor context from Acceptor
    func generateAcceptorContext(_ acceptor: WaitableTrait.Acceptor) -> AcceptorContext {
        switch acceptor.matcher {
        case .output(let pathMatcher):
            let expected = self.generateExpectedValue(expected: pathMatcher.expected)
            let path = self.generatePathArgument(argument: pathMatcher.path)
            switch pathMatcher.comparator {
            case .stringEquals, .booleanEquals:
                return .init(state: acceptor.state.rawValue, matcher: .jmesPath(path: path, expected: expected))
            case .anyStringEquals:
                return .init(state: acceptor.state.rawValue, matcher: .jmesAnyPath(path: path, expected: expected))
            case .allStringEquals:
                return .init(state: acceptor.state.rawValue, matcher: .jmesAllPath(path: path, expected: expected))
            }

        case .errorType(let error):
            return .init(state: acceptor.state.rawValue, matcher: .error(error))

        case .success:
            return .init(state: acceptor.state.rawValue, matcher: .success(0))

        case .inputOutput:
            preconditionFailure("Waiter inputOutput acceptors are not supported")
        }
    }

    /// Parse JMESPath to make it work with Soto structs instead of the output JSON
    /// Basically convert all fields into format used for variables - ie lowercase first character
    func generatePathArgument(argument: String) -> String {
        // a field is any series of letters that doesn't end with a `(`
        var output: String = ""
        var index = argument.startIndex
        var fieldStartIndex: String.Index?
        while index != argument.endIndex {
            if argument[index].isLetter {
                if fieldStartIndex == nil {
                    fieldStartIndex = index
                }
            } else {
                if let startIndex = fieldStartIndex {
                    fieldStartIndex = nil
                    if argument[index] != "(" {
                        output += String(argument[startIndex...index]).toSwiftLabelCase()
                    } else {
                        output += argument[startIndex...index]
                    }
                } else {
                    output.append(argument[index])
                }
            }
            index = argument.index(after: index)
        }
        if let startIndex = fieldStartIndex {
            output += argument[startIndex].lowercased()
            output += argument[argument.index(after: startIndex)...]
        }
        return output
    }

    func generateExpectedValue(expected: String) -> String {
        return "\"\(expected)\""
    }
}
