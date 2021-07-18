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
import SotoSmithyAWS

extension AwsService {
    /// Generate context for outputting Shapes
    func generateShapesContext() throws -> [String: Any] {
        var context: [String: Any] = [:]
        context["name"] = serviceName
        
        markInputOutputShapes(model)
        
        var shapeContexts: [[String: Any]] = []

        // generate enums
        let enums = try model.select(from: "[trait|enum]").map { (key: $0.key.shapeName, value: $0.value) }.sorted { $0.key < $1.key }
        for e in enums {
            guard let enumContext = self.generateEnumContext(e.value, shapeName: e.key) else { continue }
            shapeContexts.append(["enum": enumContext])
        }
        
        // generate structures
        let structures = model.select(type: StructureShape.self).sorted { $0.key.shapeName < $1.key.shapeName }
        for structure in structures {
            guard let shapeContext = self.generateStructureContext(structure.value, shapeId: structure.key) else { continue }
            shapeContexts.append(["struct": shapeContext])
        }

        // generate unions
        let unions = model.select(type: UnionShape.self).map { (key: $0.key.shapeName, value: $0) }.sorted { $0.key < $1.key }
        for union in unions {
            guard let shapeContext = self.generateStructureContext(union.value.value, shapeId: union.value.key) else { continue }
            shapeContexts.append(["enumWithValues": shapeContext])
        }

        if shapeContexts.count > 0 {
            context["shapes"] = shapeContexts
        }
        return context
    }

    /// Generate the context information for outputting an enum
    func generateEnumContext(_ shape: Shape, shapeName: String) -> EnumContext? {
        guard let trait = shape.trait(type: EnumTrait.self) else { return nil }
        let usedInInput = shape.hasTrait(type: SotoInputShapeTrait.self)
        let usedInOutput = shape.hasTrait(type: SotoOutputShapeTrait.self)
        guard usedInInput || usedInOutput else { return nil }
        
        // Operations
        var valueContexts: [EnumMemberContext] = []
        let enumDefinitions = trait.value.sorted { $0.value < $1.value }
        for value in enumDefinitions {
            var key = value.value.lowercased()
                .replacingOccurrences(of: ".", with: "_")
                .replacingOccurrences(of: ":", with: "_")
                .replacingOccurrences(of: "-", with: "_")
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "(", with: "_")
                .replacingOccurrences(of: ")", with: "_")
                .replacingOccurrences(of: "*", with: "all")

            if Int(String(key[key.startIndex])) != nil { key = "_" + key }

            var caseName = key.camelCased().reservedwordEscaped()
            if caseName.allLetterIsNumeric() {
                caseName = "\(shapeName.toSwiftVariableCase())\(caseName)"
            }
            valueContexts.append(EnumMemberContext(case: caseName, documentation: processDocs(value.documentation), string: value.value))
        }
        return EnumContext(
            name: shapeName.toSwiftClassCase().reservedwordEscaped(),
            documentation: processDocs(from: shape),
            values: valueContexts,
            isExtensible: shape.hasTrait(type: SotoExtensibleEnumTrait.self)
        )
    }

    /// Generate the context information for outputting a shape
    func generateStructureContext(_ shape: CollectionShape, shapeId: ShapeId) -> StructureContext? {
        let shapeName = shapeId.shapeName
        var shapePayloadOptions: [String] = []
        var xmlNamespace: String?
        let payloadMember = getPayloadMember(from: shape)
        
        guard let shapeProtocol = getShapeProtocol(shape, hasPayload: payloadMember != nil) else { return nil }
        
        let contexts = generateMembersContexts(shape, shapeName: shapeName, typeIsEnum: shape is UnionShape)
        
        // get payload options
        if let payloadMember = payloadMember, let payload = model.shape(for: payloadMember.value.target) {
            if payload is BlobShape {
                shapePayloadOptions.append("raw")
                if payload.hasTrait(type: StreamingTrait.self) {
                    shapePayloadOptions.append("allowStreaming")
                    if shape.hasTrait(type: SotoAuthUnsignedPayloadTrait.self) {
                        shapePayloadOptions.append("allowChunkedStreaming")
                    }
                }
            }
        }
        if serviceProtocolTrait is AwsProtocolsRestXmlTrait {
            xmlNamespace = shape.trait(type: XmlNamespaceTrait.self)?.uri ?? service.trait(type: XmlNamespaceTrait.self)?.uri
        }
        let recursive = doesShapeHaveRecursiveOwnReference(shape, shapeId: shapeId)
        
        return StructureContext(
            object: recursive ? "class": "struct",
            name: shapeName.toSwiftClassCase(),
            shapeProtocol: shapeProtocol,
            payload: payloadMember?.key.toSwiftLabelCase(),
            payloadOptions: shapePayloadOptions.count > 0 ? shapePayloadOptions.map { ".\($0)" }.joined(separator: ", ") : nil,
            namespace: xmlNamespace,
            isEncodable: shape.hasTrait(type: SotoInputShapeTrait.self),
            isDecodable: shape.hasTrait(type: SotoOutputShapeTrait.self),
            encoding: contexts.encoding,
            members: contexts.members,
            awsShapeMembers: contexts.awsShapeMembers,
            codingKeys: contexts.codingKeys,
            validation: contexts.validation,
            requiresDefaultValidation: contexts.validation.count != contexts.members.count
        )
    }

    struct MembersContexts {
        var members: [MemberContext] = []
        var awsShapeMembers: [MemberEncodingContext] = []
        var codingKeys: [CodingKeysContext] = []
        var validation: [ValidationContext] = []
        var encoding: [EncodingPropertiesContext] = []
    }
    
    /// generate shape members context
    func generateMembersContexts(_ shape: CollectionShape, shapeName: String, typeIsEnum: Bool) -> MembersContexts {
        var contexts = MembersContexts()
        guard let members = shape.members else { return contexts }
        let isOutputShape = shape.hasTrait(type: SotoOutputShapeTrait.self)
        let isInputShape = shape.hasTrait(type: SotoInputShapeTrait.self)
        let sortedMembers = members.map{ $0 }.sorted { $0.key.lowercased() < $1.key.lowercased() }
        for member in sortedMembers {
            // member context
            let memberContext = generateMemberContext(member.value, name: member.key, shapeName: shapeName, typeIsEnum: typeIsEnum)
            contexts.members.append(memberContext)
            // coding key context
            if let codingKeyContext = generateCodingKeyContext(member.value, name: member.key, isOutputShape: isOutputShape) {
                contexts.codingKeys.append(codingKeyContext)
            }
            // member encoding context
            if let memberEncodingContext = generateMemberEncodingContext(
                member.value,
                name: member.key,
                isOutputShape: isOutputShape,
                isPropertyWrapper: memberContext.propertyWrapper != nil && isInputShape
            ) {
                contexts.awsShapeMembers.append(memberEncodingContext)
            }
            // validation context
            if isInputShape {
                if let validationContext = generateValidationContext(member.value, name: member.key) {
                    contexts.validation.append(validationContext)
                }
            }
            if let encodingPropertyContex = generateEncodingPropertyContext(member.value, name: member.key) {
                contexts.encoding.append(encodingPropertyContex)
            }
        }
        return contexts
    }

    func generateMemberContext(_ member: MemberShape, name: String, shapeName: String, typeIsEnum: Bool) -> MemberContext {
        let required = member.hasTrait(type: RequiredTrait.self)
        let idempotencyToken = member.hasTrait(type: IdempotencyTokenTrait.self)
        let defaultValue: String?
        if idempotencyToken == true {
            defaultValue = "\(shapeName.toSwiftClassCase()).idempotencyToken()"
        } else if !required {
            defaultValue = "nil"
        } else {
            defaultValue = nil
        }
        let type = member.output(model)
        return MemberContext(
            variable: name.toSwiftVariableCase(),
            parameter: name.toSwiftLabelCase(),
            required: member.hasTrait(type: RequiredTrait.self),
            default: defaultValue,
            propertyWrapper: generatePropertyWrapper(member, name: name, required: required),
            type: type + ((required || typeIsEnum) ? "" : "?"),
            comment: processMemberDocs(from: member),
            duplicate: false // NEED to catch this
        )
    }

    func generateMemberEncodingContext(_ member: MemberShape, name: String, isOutputShape: Bool, isPropertyWrapper: Bool) -> MemberEncodingContext? {
        // if header
        if let headerTrait = member.trait(type: HttpHeaderTrait.self) {
            let name = isPropertyWrapper ? "_\(name.toSwiftLabelCase())" : name.toSwiftLabelCase()
            return MemberEncodingContext(name: name, location: ".header(locationName: \"\(headerTrait.value)\")")
        // if prefix header
        } else if let headerPrefixTrait = member.trait(type: HttpPrefixHeadersTrait.self) {
            let name = isPropertyWrapper ? "_\(name.toSwiftLabelCase())" : name.toSwiftLabelCase()
            return MemberEncodingContext(name: name, location: ".header(locationName: \"\(headerPrefixTrait.value)\")")
        // if query string
        } else if let queryTrait = member.trait(type: HttpQueryTrait.self) {
            let name = isPropertyWrapper ? "_\(name.toSwiftLabelCase())" : name.toSwiftLabelCase()
            return MemberEncodingContext(name: name, location: ".querystring(locationName: \"\(queryTrait.value)\")")
        // if part of URL
        } else if member.hasTrait(type: HttpLabelTrait.self) {
            let labelName = isPropertyWrapper ? "_\(name.toSwiftLabelCase())" : name.toSwiftLabelCase()
            let aliasTrait = member.trait(named: serviceProtocolTrait.nameTrait.staticName) as? AliasTrait
            return MemberEncodingContext(name: labelName, location: ".uri(locationName: \"\(aliasTrait?.alias ?? name)\")")
        // if response status code
        } else if member.hasTrait(type: HttpResponseCodeTrait.self) {
            let name = isPropertyWrapper ? "_\(name.toSwiftLabelCase())" : name.toSwiftLabelCase()
            return MemberEncodingContext(name: name, location: ".statusCode")
        // if payload and not a blob or shape is an output shape
        } else if member.hasTrait(type: HttpPayloadTrait.self),
                  (!(model.shape(for: member.target) is BlobShape) || isOutputShape) {
            let aliasTrait = member.traits?.first(where: {$0 is AliasTrait}) as? AliasTrait
            let payloadName = aliasTrait?.alias ?? name
            let swiftLabelName = name.toSwiftLabelCase()
            if swiftLabelName != payloadName {
                let name = isPropertyWrapper ? "_\(name.toSwiftLabelCase())" : name.toSwiftLabelCase()
                return MemberEncodingContext(name: name, location: ".body(locationName: \"\(payloadName)\")")
            }
        }
        return nil
    }
    
    func generateCodingKeyContext(_ member: MemberShape, name: String, isOutputShape: Bool) -> CodingKeysContext? {
        guard isOutputShape ||
                (!member.hasTrait(type: HttpHeaderTrait.self) &&
                    !member.hasTrait(type: HttpPrefixHeadersTrait.self) &&
                    !member.hasTrait(type: HttpQueryTrait.self) &&
                    !member.hasTrait(type: HttpLabelTrait.self) &&
                    !(member.hasTrait(type: HttpPayloadTrait.self) && model.shape(for: member.target) is BlobShape)) else {
            return nil
        }
        var codingKey: String = name
        if let aliasTrait = member.traits?.first(where: {$0 is AliasTrait}) as? AliasTrait {
            codingKey = aliasTrait.alias
        }
        return CodingKeysContext(variable: name.toSwiftVariableCase(), codingKey: codingKey, duplicate: false)
    }

    /// Generate array/dictionary encoding contexts
    func generateEncodingPropertyContext(_ member: MemberShape, name: String) -> EncodingPropertiesContext? {
        guard let memberShape = model.shape(for: member.target) else { return nil }
        switch memberShape {
        case let list as ListShape:
            guard self.serviceProtocolTrait.requiresCollectionCoders else { return nil }
            let memberName = getListEntryName(member: member, list: list)
            guard let validMemberName = memberName, validMemberName != "member" else { return nil }
            return ArrayEncodingPropertiesContext(name: self.encodingName(name), member: validMemberName)
        case let map as MapShape:
            guard self.serviceProtocolTrait.requiresCollectionCoders else { return nil }
            let names = getMapEntryNames(member: member, map: map)
            guard names.entry != "entry" || names.key != "key" || names.value != "value" else { return nil }
            return DictionaryEncodingPropertiesContext(name: self.encodingName(name), entry: names.entry, key: names.key, value: names.value)
        default:
            return nil
        }
    }

    func generatePropertyWrapper(_ member: MemberShape, name: String, required: Bool) -> String? {
        let memberShape = model.shape(for: member.target)
        let codingWrapper: String
        if required {
            codingWrapper = "@CustomCoding"
        } else {
            codingWrapper = "@OptionalCustomCoding"
        }

        switch memberShape {
        case let list as ListShape:
            guard isMemberInBody(member) else { return nil }
            guard self.serviceProtocolTrait.requiresCollectionCoders else { return nil }
            let memberName = getListEntryName(member: member, list: list)
            guard let validMemberName = memberName else { return nil }
            if validMemberName == "member" {
                return "\(codingWrapper)<StandardArrayCoder>"
            } else {
                return "\(codingWrapper)<ArrayCoder<\(self.encodingName(name)), \(list.member.output(model))>>"
            }
        case let map as MapShape:
            guard isMemberInBody(member) else { return nil }
            guard self.serviceProtocolTrait.requiresCollectionCoders else { return nil }
            let names = getMapEntryNames(member: member, map: map)
            if names.entry == "entry", names.key == "key", names.value == "value" {
                return "\(codingWrapper)<StandardDictionaryCoder>"
            } else {
                return "\(codingWrapper)<DictionaryCoder<\(self.encodingName(name)), \(map.key.output(model)), \(map.value.output(model))>>"
            }
        case let timestamp as TimestampShape:
            if let formatTrait = timestamp.trait(type: TimestampFormatTrait.self) {
                switch formatTrait.value {
                case .datetime:
                    return "\(codingWrapper)<ISO8601DateCoder>"
                case .epochSeconds:
                    return "\(codingWrapper)<UnixEpochDateCoder>"
                case .httpDate:
                    return "\(codingWrapper)<HTTPHeaderDateCoder>"
                }
            } else if member.hasTrait(type: HttpHeaderTrait.self) {
                return "\(codingWrapper)<HTTPHeaderDateCoder>"
            }
            return nil
        default:
            return nil
        }
    }

    func generateValidationContext(_ shapeId: ShapeId, name: String, required: Bool, container: Bool = false, alreadyProcessed: Set<ShapeId>) -> ValidationContext? {
        guard !alreadyProcessed.contains(shapeId) else { return nil }
        guard let shape = model.shape(for: shapeId) else { return nil }
        guard !shape.hasTrait(type: EnumTrait.self) else { return nil }
        
        var requirements: [String: Any] = [:]
        if let lengthTrait = shape.trait(type: LengthTrait.self) {
            if let min = lengthTrait.min, min > 0 {
                requirements["min"] = min
            }
            requirements["max"] = lengthTrait.max
        }
        if let rangeTrait = shape.trait(type: RangeTrait.self) {
            if shape is FloatShape || shape is DoubleShape || shape is BigDecimalShape {
                requirements["min"] = rangeTrait.min
                requirements["max"] = rangeTrait.max
            } else {
                requirements["min"] = rangeTrait.min.map { NSNumber(value: $0).int64Value }
                requirements["max"] = rangeTrait.max.map { NSNumber(value: $0).int64Value }
            }
        }
        if let patternTrait = shape.trait(type: PatternTrait.self) {
            requirements["pattern"] = "\"\(patternTrait.value.addingBackslashEncoding())\""
        }
        
        var listMember: MemberShape? = nil
        if let list = shape as? ListShape {
            listMember = list.member
        } else if let set = shape as? SetShape {
            listMember = set.member
        }
        if let listMember = listMember {
            // validation code doesn't support containers inside containers. Only service affected by this is SSM
            if !container {
                if let memberValidationContext = generateValidationContext(
                    listMember.target,
                    name: name,
                    required: required,
                    container: true,
                    alreadyProcessed: alreadyProcessed
                ) {
                    return ValidationContext(
                        name: name.toSwiftVariableCase(),
                        required: required,
                        reqs: requirements,
                        member: memberValidationContext
                    )
                }
            }
        }
        
        if let map = shape as? MapShape {
            // validation code doesn't support containers inside containers. Only service affected by this is SSM
            if !container {
                let keyValidationContext = generateValidationContext(
                    map.key.target,
                    name: name,
                    required: required,
                    container: true,
                    alreadyProcessed: alreadyProcessed
                )
                let valueValidationContext = generateValidationContext(
                    map.value.target,
                    name: name,
                    required: required,
                    container: true,
                    alreadyProcessed: alreadyProcessed
                )
                if keyValidationContext != nil || valueValidationContext != nil {
                    return ValidationContext(
                        name: name.toSwiftVariableCase(),
                        required: required,
                        reqs: requirements,
                        keyValidation: keyValidationContext,
                        valueValidation: valueValidationContext
                    )
                }
            }
        }
        
        if let collection = shape as? CollectionShape, let members = collection.members {
            for member in members {
                let memberRequired = member.value.hasTrait(type: RequiredTrait.self)
                var alreadyProcessed2 = alreadyProcessed
                alreadyProcessed2.insert(shapeId)
                if generateValidationContext(
                    member.value.target,
                    name: member.key,
                    required: memberRequired,
                    container: false,
                    alreadyProcessed: alreadyProcessed2
                ) != nil {
                    return ValidationContext(name: name.toSwiftVariableCase(), shape: true, required: required)
                }
            }

        }
        if requirements.count > 0 {
            return ValidationContext(name: name.toSwiftVariableCase(), required: required, reqs: requirements)
        }
        return nil
    }
    
    func generateValidationContext(_ member: MemberShape, name: String) -> ValidationContext? {
        let required = member.hasTrait(type: RequiredTrait.self)
        return generateValidationContext(member.target, name: name, required: required, container: false, alreadyProcessed: [])
    }
}
