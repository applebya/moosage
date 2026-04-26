import Foundation

public enum Plan: String, CaseIterable, Codable {
    case pro
    case max5x
    case max20x

    // Calibrated against an observed data point: Claude.ai showed 94% used
    // when local JSONL token sum was 88.5M on Max 5×, implying a real cap of
    // ~94M for Max 5×. Pro/Max 20× scaled by the same ratio (~7%).
    public var tokensPer5hBlock: Int {
        switch self {
        case .pro:    return  20_000_000
        case .max5x:  return  94_000_000
        case .max20x: return 235_000_000
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
