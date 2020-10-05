//===----------------------------------------------------------------------===//
//
// This source file is part of the Soto for AWS open source project
//
// Copyright (c) 2020 the Soto project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Soto project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

public struct AllSelector: Selector {
    public func select(using model: Model, shape: Shape) -> Bool {
        return true
    }
}

public struct ShapeSelector<S: Shape>: Selector {
    public func select(using model: Model, shape: Shape) -> Bool {
        return type(of: shape) == S.self
    }
}

public struct NumberSelector: Selector {
    public func select(using model: Model, shape: Shape) -> Bool {
        return
            shape is ByteShape ||
            shape is ShortShape ||
            shape is IntegerShape ||
            shape is LongShape ||
            shape is FloatShape ||
            shape is DoubleShape ||
            shape is BigDecimalShape ||
            shape is BigIntegerShape
    }
}

public struct TargetSelector: Selector {
    let selector: Selector
    init(_ selector: Selector) {
        self.selector = selector
    }
    public func select(using model: Model, shape: Shape) -> Bool {
        guard let member = shape as? MemberShape else { return false }
        guard let memberShape = model.shape(for: member.target) else { return false }
        return selector.select(using: model, shape: memberShape)
    }
}

public struct OrTargetSelector: Selector {
    let selector: Selector
    init(_ selector: Selector) {
        self.selector = selector
    }
    public func select(using model: Model, shape: Shape) -> Bool {
        if selector.select(using: model, shape: shape) {
            return true
        }
        guard let member = shape as? MemberShape else { return false }
        guard let memberShape = model.shape(for: member.target) else { return false }
        return selector.select(using: model, shape: memberShape)
    }
}

public struct TraitSelector<T: Trait>: Selector {
    public func select(using model: Model, shape: Shape) -> Bool {
        return shape.traits?.trait(type: T.self) != nil
    }
}

public struct NotSelector: Selector {
    let selector: Selector
    public init(_ selector: Selector) {
        self.selector = selector
    }

    public func select(using model: Model, shape: Shape) -> Bool {
        return !selector.select(using: model, shape: shape)
    }
}

public struct AndSelector: Selector {
    let selectors: [Selector]
    public init(_ selectors: Selector...) {
        self.selectors = selectors
    }

    public func select(using model: Model, shape: Shape) -> Bool {
        for selector in selectors {
            if selector.select(using: model, shape: shape) == false {
                return false
            }
        }
        return true
    }
}

public struct OrSelector: Selector {
    let selectors: [Selector]
    public init(_ selectors: Selector...) {
        self.selectors = selectors
    }

    public func select(using model: Model, shape: Shape) -> Bool {
        for selector in selectors {
            if selector.select(using: model, shape: shape) == true {
                return true
            }
        }
        return false
    }
}

