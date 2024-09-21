//===----------------------------------------------------------------------===//
//
// This source file is part of the Soto for AWS open source project
//
// Copyright (c) 2017-2022 the Soto project authors
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
    /// Generate paginator context
    func generatePaginatorContext() throws -> [String: Any] {
        let paginatorOperations = self.operations.filter { $0.value.hasTrait(type: PaginatedTrait.self) }
        guard paginatorOperations.count > 0 else { return [:] }
        var context: [String: Any] = ["name": serviceName]
        let namespace = paginatorOperations.first?.key.namespace

        var paginatorContexts: [PaginatorContext] = []
        var paginatorShapeMap: [String: OperationShape] = [:]

        // build list of operations that can be paginated
        for operation in paginatorOperations {
            let operationShape = operation.value
            guard let paginatedTrait = operationShape.trait(type: PaginatedTrait.self) else { continue }
            guard let input = operationShape.input?.target else { continue }
            guard let inputShape = model.shape(for: input) as? StructureShape else { continue }
            guard let inputToken = paginatedTrait.inputToken else { continue }
            guard let inputMember = inputShape.members?[inputToken] else { continue }
            guard let output = operationShape.output?.target else { continue }
            guard let outputShape = model.shape(for: output) as? StructureShape else { continue }
            guard let outputToken = paginatedTrait.outputToken else { continue }
            let paginatedTruncatedTrait = operationShape.trait(type: SotoPaginationTruncatedTrait.self)

            // add input shape name to paginator shape set
            paginatorShapeMap[input.shapeName] = operationShape

            var inputKeyToken: String? = inputToken
            guard let inputKeyShape = model.shape(for: inputMember.target) else { continue }
            // if input key shape is not equatable then don't output input key
            if !(inputKeyShape is SotoEquatableShape) {
                inputKeyToken = nil
            }
            // if we have a `isTruncated` flag then don't output input
            if paginatedTruncatedTrait != nil {
                inputKeyToken = nil
            }

            var operation = try self.generateOperationContext(operationShape, operationName: operation.key, streaming: false)
            if let inputKeyToken {
                operation.initParameters = operation.initParameters?.filter { $0.parameter != inputKeyToken.toSwiftVariableCase() }
            }
            paginatorContexts.append(
                PaginatorContext(
                    operation: operation,
                    inputKey: inputKeyToken.map { self.toKeyPath(token: $0, structure: inputShape) },
                    outputKey: self.toKeyPath(token: outputToken, structure: outputShape),
                    moreResultsKey: paginatedTruncatedTrait.map { self.toKeyPath(token: $0.isTruncated, structure: outputShape) }
                )
            )
        }

        paginatorContexts.sort { $0.operation.funcName < $1.operation.funcName }
        if paginatorContexts.count > 0 {
            context["paginators"] = paginatorContexts
        }

        var paginatorShapeContexts: [PaginatorShapeContext] = []

        // build list of input shapes that need pagination support
        for shape in paginatorShapeMap {
            guard let paginatedTrait = shape.value.trait(type: PaginatedTrait.self) else { continue }
            guard let input = shape.value.input?.target else { continue }
            guard let inputShape = model.shape(for: input) as? StructureShape else { continue }
            guard let inputToken = paginatedTrait.inputToken else { continue }
            guard let inputMember = inputShape.members?[inputToken] else { continue }
            let inputMemberShapeName = inputMember.output(self.model, withServiceName: self.serviceName)

            // construct array of input shape parameters to use in `usingPaginationToken` function
            var initParams: [String: String] = [:]
            for member in inputShape.members ?? [:] {
                // don't include deprecated members
                guard !member.value.hasTrait(type: DeprecatedTrait.self) else { continue }
                initParams[member.key.toSwiftLabelCase()] = "self.\(member.key.toSwiftLabelCase())"
            }
            initParams[inputToken.toSwiftLabelCase()] = "token"
            let initParamsArray = initParams.map { "\($0.key): \($0.value)" }.sorted { $0.lowercased() < $1.lowercased() }

            paginatorShapeContexts.append(
                PaginatorShapeContext(
                    inputShape: shape.key,
                    initParams: initParamsArray,
                    paginatorProtocol: "AWSPaginateToken",
                    tokenType: inputMemberShapeName
                )
            )
        }

        paginatorShapeContexts.sort { $0.inputShape < $1.inputShape }
        if paginatorShapeContexts.count > 0 {
            context["paginatorShapes"] = paginatorShapeContexts
        }

        context["logger"] = self.getSymbol(for: "Logger", from: "Logging", model: self.model, namespace: namespace ?? "")
        return context
    }
}
