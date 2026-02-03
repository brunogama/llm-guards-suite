import Foundation

enum CanonicalJSON {
  static func encode(_ value: Any) throws -> Data {
    let normalized = try normalize(value)
    var buffer = Data()
    try write(normalized, into: &buffer)
    return buffer
  }

  private static func normalize(_ value: Any) throws -> Any {
    switch value {
    case let dict as [String: Any]:
      // sort keys
      var out: [(String, Any)] = []
      out.reserveCapacity(dict.count)
      for (k, v) in dict {
        out.append((k, try normalize(v)))
      }
      out.sort { $0.0 < $1.0 }
      return out  // array of (k,v) pairs for stable writing
    case let array as [Any]:
      return try array.map { try normalize($0) }
    case is NSNull, is String, is NSNumber, is Bool:
      return value
    default:
      // JSONSerialization uses NSNumber for bool/int/double. Keep it.
      return value
    }
  }

  private static func write(_ value: Any, into data: inout Data) throws {
    switch value {
    case let pairs as [(String, Any)]:
      data.append(asciiValue("{"))
      var first = true
      for (k, v) in pairs {
        if !first { data.append(asciiValue(",")) }
        first = false
        try writeString(k, into: &data)
        data.append(asciiValue(":"))
        try write(v, into: &data)
      }
      data.append(asciiValue("}"))

    case let array as [Any]:
      data.append(asciiValue("["))
      for i in array.indices {
        if i != array.startIndex { data.append(asciiValue(",")) }
        try write(array[i], into: &data)
      }
      data.append(asciiValue("]"))

    case let s as String:
      try writeString(s, into: &data)

    case let n as NSNumber:
      // Preserve booleans
      if CFGetTypeID(n) == CFBooleanGetTypeID() {
        data.append(contentsOf: (n.boolValue ? "true" : "false").utf8)
      } else {
        data.append(contentsOf: n.stringValue.utf8)
      }

    case let b as Bool:
      data.append(contentsOf: (b ? "true" : "false").utf8)

    case is NSNull:
      data.append(contentsOf: "null".utf8)

    default:
      throw NSError(
        domain: "CanonicalJSON", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Unsupported JSON value: \(type(of: value))"])
    }
  }

  private static func writeString(_ s: String, into data: inout Data) throws {
    let escaped =
      s
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\n", with: "\\n")
      .replacingOccurrences(of: "\r", with: "\\r")
      .replacingOccurrences(of: "\t", with: "\\t")
    data.append(asciiValue("\""))
    data.append(contentsOf: escaped.utf8)
    data.append(asciiValue("\""))
  }

  /// Convert single ASCII character to UInt8
  private static func asciiValue(_ char: Unicode.Scalar) -> UInt8 {
    UInt8(ascii: char)
  }
}
