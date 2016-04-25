
import Accelerate

public struct Tensor {
    public typealias Element = Float
    
    public let shape: Shape
    public private(set) var elements: [Element]
    
    public init(shape: Shape, elements: [Element]) {
        let c = shape.volume
        assert(elements.count >= c, "`elements.count` must be greater than or equal to `shape.volume`: elements.count = \(elements.count), shape.volume = \(shape.volume)")
        self.shape = shape
        self.elements = (elements.count == c) ? elements : Array(elements[0..<c])
    }
}

extension Tensor { // Additional Initializers
    public init(shape: Shape, element: Element = 0.0) {
        self.init(shape: shape, elements: [Element](count: shape.volume, repeatedValue: element))
    }
}

extension Tensor { // like CollentionType
    internal func index(indices: [Int]) -> Int {
        assert(indices.count == shape.dimensions.count, "`indices.count` must be \(shape.dimensions.count): \(indices.count)")
        return zip(shape.dimensions, indices).reduce(0) {
            assert(0 <= $1.1 && $1.1 < $1.0.value, "Illegal index: indices = \(indices), shape = \(shape)")
            return $0 * $1.0.value + $1.1
        }
    }
    
    public subscript(indices: Int...) -> Element {
        get {
            return elements[index(indices)]
        }
        set {
            elements[index(indices)] = newValue
        }
    }
    
    public var volume: Int {
        return shape.volume
    }
}

extension Tensor: SequenceType {
    public func generate() -> IndexingGenerator<[Element]> {
        return elements.generate()
    }
}

extension Tensor: Equatable {}
public func ==(lhs: Tensor, rhs: Tensor) -> Bool {
    assert(lhs.shape == rhs.shape, "Incompatible shapes of tensors: lhs.shape = \(lhs.shape), rhs.shape = \(rhs.shape)")
    return lhs.elements == rhs.elements
}

public func +(lhs: Tensor, rhs: Tensor) -> Tensor {
    assert(lhs.shape == rhs.shape, "Incompatible shapes of tensors: lhs.shape = \(lhs.shape), rhs.shape = \(rhs.shape)")
    return Tensor(shape: lhs.shape, elements: zip(lhs.elements, rhs.elements).map(+))
}

public func -(lhs: Tensor, rhs: Tensor) -> Tensor {
    assert(lhs.shape == rhs.shape, "Incompatible shapes of tensors: lhs.shape = \(lhs.shape), rhs.shape = \(rhs.shape)")
    return Tensor(shape: lhs.shape, elements: zip(lhs.elements, rhs.elements).map(-))
}

public func *(lhs: Tensor, rhs: Tensor) -> Tensor {
    assert(lhs.shape == rhs.shape, "Incompatible shapes of tensors: lhs.shape = \(lhs.shape), rhs.shape = \(rhs.shape)")
    return Tensor(shape: lhs.shape, elements: zip(lhs.elements, rhs.elements).map(*))
}

public func /(lhs: Tensor, rhs: Tensor) -> Tensor {
    assert(lhs.shape == rhs.shape, "Incompatible shapes of tensors: lhs.shape = \(lhs.shape), rhs.shape = \(rhs.shape)")
    return Tensor(shape: lhs.shape, elements: zip(lhs.elements, rhs.elements).map(/))
}

public func *(lhs: Tensor, rhs: Float) -> Tensor {
    return Tensor(shape: lhs.shape, elements: lhs.elements.map { $0 * rhs })
}

public func *(lhs: Float, rhs: Tensor) -> Tensor {
    return Tensor(shape: rhs.shape, elements: rhs.elements.map { $0 * lhs })
}

public func /(lhs: Tensor, rhs: Float) -> Tensor {
    return Tensor(shape: lhs.shape, elements: lhs.elements.map { $0 / rhs })
}

extension Tensor { // Matrix
    public func matmul(tensor: Tensor) -> Tensor {
        assert(shape.dimensions.count == 2, "This tensor is not a matrix: shape = \(shape)")
        assert(tensor.shape.dimensions.count == 2, "The given tensor is not a matrix: shape = \(tensor.shape)")
        
        let n = shape.dimensions[1]
        assert(tensor.shape.dimensions[0] == n, "Incompatible shapes of matrices: self.shape = \(shape), tensor.shape = \(tensor.shape)")
        
        let M = shape.dimensions[0]
        let N = tensor.shape.dimensions[1]
        let K = shape.dimensions[1]
        
        let z = Tensor(shape: [M, N])
        
        let c = UnsafeMutablePointer<Float>(z.elements)
        
        cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans,
                    Int32(M.value), Int32(N.value), Int32(K.value), 1.0,
                    self.elements, Int32(K.value),
                    tensor.elements, Int32(N.value), 1.0,
                    c, Int32(N.value))
        
        return z
    }
}
