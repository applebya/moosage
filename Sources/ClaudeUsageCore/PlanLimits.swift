import Foundation

public enum Plan: String, CaseIterable, Codable {
    case pro
    case max5x
    case max20x

    public var tokensPer5hBlock: Int {
        switch self {
        case .pro:    return  19_000_000
        case .max5x:  return  88_000_000
        case .max20x: return 220_000_000
        }
    }

    public var displayName: String {
        switch self {
        case .pro:    return "Pro"
        case .max5x:  return "Max 5×"
        case .max20x: return "Max 20×"
        }
    }
}
