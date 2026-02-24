import Foundation

/// Central unit conversion helpers.
/// All data is stored in metric (°C, kg, cm, ml).
/// Conversions happen at the display/input layer only.
struct UnitConversion {
    private static var settings: AppSettings { AppSettings.shared }

    // MARK: - Temperature (°C ↔ °F)

    static func celsiusToFahrenheit(_ c: Double) -> Double { c * 9.0 / 5.0 + 32.0 }
    static func fahrenheitToCelsius(_ f: Double) -> Double { (f - 32.0) * 5.0 / 9.0 }

    /// Format temperature for display in user's preferred unit
    static func formatTemp(_ celsius: Double) -> String {
        if settings.useCelsius {
            return String(format: "%.1f°C", celsius)
        } else {
            return String(format: "%.1f°F", celsiusToFahrenheit(celsius))
        }
    }

    /// Convert stored °C to display value
    static func displayTemp(_ celsius: Double) -> Double {
        settings.useCelsius ? celsius : celsiusToFahrenheit(celsius)
    }

    /// Convert display value back to °C for storage
    static func storageTemp(_ display: Double) -> Double {
        settings.useCelsius ? display : fahrenheitToCelsius(display)
    }

    static var tempUnit: String { settings.useCelsius ? "°C" : "°F" }
    static var tempSliderMin: Double { settings.useCelsius ? 35.0 : 95.0 }
    static var tempSliderMax: Double { settings.useCelsius ? 42.0 : 107.6 }
    static var tempSliderStep: Double { 0.1 }

    // MARK: - Weight (kg ↔ lbs)

    static func kgToLbs(_ kg: Double) -> Double { kg * 2.20462 }
    static func lbsToKg(_ lbs: Double) -> Double { lbs / 2.20462 }

    /// Format weight for display
    static func formatWeight(_ kg: Double, decimals: Int = 2) -> String {
        if settings.useMetric {
            return String(format: "%.\(decimals)f kg", kg)
        } else {
            return String(format: "%.\(decimals)f lbs", kgToLbs(kg))
        }
    }

    static func displayWeight(_ kg: Double) -> Double {
        settings.useMetric ? kg : kgToLbs(kg)
    }

    static func storageWeight(_ display: Double) -> Double {
        settings.useMetric ? display : lbsToKg(display)
    }

    static var weightUnit: String { settings.useMetric ? "kg" : "lbs" }

    // MARK: - Height/Length (cm ↔ in)

    static func cmToInches(_ cm: Double) -> Double { cm / 2.54 }
    static func inchesToCm(_ inches: Double) -> Double { inches * 2.54 }

    /// Format height for display. Uses feet+inches for values > 24 inches when imperial.
    static func formatHeight(_ cm: Double) -> String {
        if settings.useMetric {
            return String(format: "%.1f cm", cm)
        } else {
            let totalInches = cmToInches(cm)
            if totalInches >= 24 {
                let feet = Int(totalInches) / 12
                let inches = Int(totalInches) % 12
                return "\(feet)'\(inches)\""
            }
            return String(format: "%.1f in", totalInches)
        }
    }

    /// Format height for chart axis (shorter format)
    static func formatHeightShort(_ cm: Double) -> String {
        if settings.useMetric {
            return String(format: "%.0f", cm)
        } else {
            return String(format: "%.1f", cmToInches(cm))
        }
    }

    static func displayHeight(_ cm: Double) -> Double {
        settings.useMetric ? cm : cmToInches(cm)
    }

    static func storageHeight(_ display: Double) -> Double {
        settings.useMetric ? display : inchesToCm(display)
    }

    static var heightUnit: String { settings.useMetric ? "cm" : "in" }

    // MARK: - Volume (ml ↔ fl oz)

    static let mlPerOz: Double = 29.5735

    static func mlToOz(_ ml: Double) -> Double { ml / mlPerOz }
    static func ozToMl(_ oz: Double) -> Double { oz * mlPerOz }

    /// Format volume for display
    static func formatVolume(_ ml: Double) -> String {
        if settings.useMetric {
            return "\(Int(ml)) ml"
        } else {
            return String(format: "%.1f oz", mlToOz(ml))
        }
    }

    static func displayVolume(_ ml: Double) -> Double {
        settings.useMetric ? ml : mlToOz(ml)
    }

    static func storageVolume(_ display: Double) -> Double {
        settings.useMetric ? display : ozToMl(display)
    }

    static var volumeUnit: String { settings.useMetric ? "ml" : "oz" }
    static var volumeSliderMin: Double { settings.useMetric ? 10 : 0.5 }
    static var volumeSliderMax: Double { settings.useMetric ? 350 : 12 }
    static var volumeSliderStep: Double { settings.useMetric ? 5 : 0.5 }

    /// Quick volume presets in the current unit (returns ml values for storage)
    static var volumePresets: [Double] {
        if settings.useMetric {
            return [30, 60, 90, 120, 150, 180, 210, 240]
        } else {
            // 1, 2, 3, 4, 5, 6, 7, 8 oz → ml
            return [1, 2, 3, 4, 5, 6, 7, 8].map { ozToMl($0) }
        }
    }

    /// Display label for a volume preset (already in ml)
    static func volumePresetLabel(_ ml: Double) -> String {
        if settings.useMetric {
            return "\(Int(ml))"
        } else {
            return "\(Int(mlToOz(ml)))"
        }
    }
}
