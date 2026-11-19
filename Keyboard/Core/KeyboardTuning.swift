import Foundation

enum LayoutMode: String, CaseIterable { case auto, unified, split }

enum TuningParameter: String, CaseIterable {
    case splitKeyScale, splitWidthThreshold, swipeThreshold, holdMilliseconds
    case cancelSlop, trackpadUnitsPerCharacter, highlightExposure, layoutMode, heightBudget

    var displayName: String {
        switch self {
        case .splitKeyScale: return "Split key scale"
        case .splitWidthThreshold: return "Split width"
        case .swipeThreshold: return "Swipe distance"
        case .holdMilliseconds: return "Hold duration"
        case .cancelSlop: return "Cancel slop"
        case .trackpadUnitsPerCharacter: return "Cursor distance"
        case .highlightExposure: return "Highlight exposure"
        case .layoutMode: return "Layout mode"
        case .heightBudget: return "Height budget"
        }
    }

    var range: ClosedRange<Double> {
        switch self {
        case .splitKeyScale: return 0.25...1.5
        case .splitWidthThreshold: return 320...1400
        case .swipeThreshold: return 20...200
        case .holdMilliseconds: return 150...1500
        case .cancelSlop: return 1...40
        case .trackpadUnitsPerCharacter: return 5...100
        case .highlightExposure: return 0...3
        case .layoutMode: return 0...2
        case .heightBudget: return 120...600
        }
    }

    var step: Double {
        switch self {
        case .splitKeyScale: return 0.05
        case .splitWidthThreshold, .heightBudget: return 10
        case .swipeThreshold, .trackpadUnitsPerCharacter: return 5
        case .holdMilliseconds: return 20
        case .highlightExposure: return 0.25
        case .cancelSlop, .layoutMode: return 1
        }
    }

    func defaultValue(tablet: Bool) -> Double {
        switch self {
        case .splitKeyScale: return tablet ? 1.0 : 0.75
        case .splitWidthThreshold: return 600
        case .swipeThreshold: return 70
        case .holdMilliseconds: return 420
        case .cancelSlop: return 10
        case .trackpadUnitsPerCharacter: return 30
        case .highlightExposure: return 1.0
        case .layoutMode: return 0
        case .heightBudget: return 320
        }
    }
}

struct KeyboardTuning {
    let tablet: Bool
    private var values: [TuningParameter: Double] = [:]
    init(tablet: Bool = false) { self.tablet = tablet }

    subscript(_ parameter: TuningParameter) -> Double {
        get { values[parameter] ?? parameter.defaultValue(tablet: tablet) }
        set {
            let valid = newValue.isFinite && parameter.range.contains(newValue)
                && (parameter != .layoutMode || newValue.rounded() == newValue)
            values[parameter] = valid ? newValue : nil
        }
    }

    var splitKeyScale: Double { self[.splitKeyScale] }
    var splitWidthThreshold: Double { self[.splitWidthThreshold] }
    var swipeThreshold: Double { self[.swipeThreshold] }
    var holdMilliseconds: Double { self[.holdMilliseconds] }
    var cancelSlop: Double { self[.cancelSlop] }
    var trackpadUnitsPerCharacter: Double { self[.trackpadUnitsPerCharacter] }
    var highlightExposure: Double { self[.highlightExposure] }
    var heightBudget: Double { self[.heightBudget] }
    var layoutMode: LayoutMode {
        get { LayoutMode.allCases[Int(self[.layoutMode])] }
        set { self[.layoutMode] = Double(LayoutMode.allCases.firstIndex(of: newValue)!) }
    }
}

struct TuningStore {
    private let defaults: UserDefaults
    private let tablet: Bool
    init(defaults: UserDefaults = .standard, tablet: Bool = false) {
        self.defaults = defaults
        self.tablet = tablet
    }

    var tuning: KeyboardTuning {
        get {
            var result = KeyboardTuning(tablet: tablet)
            for parameter in TuningParameter.allCases {
                if let value = defaults.object(forKey: "tuning.\(parameter.rawValue)") as? NSNumber,
                   CFGetTypeID(value) != CFBooleanGetTypeID() {
                    result[parameter] = value.doubleValue
                }
            }
            return result
        }
        nonmutating set {
            for parameter in TuningParameter.allCases {
                defaults.set(newValue[parameter], forKey: "tuning.\(parameter.rawValue)")
            }
        }
    }

    func reset() {
        for parameter in TuningParameter.allCases {
            defaults.removeObject(forKey: "tuning.\(parameter.rawValue)")
        }
    }
}
