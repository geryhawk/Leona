import SwiftUI

struct MealForecastView: View {
    let baby: Baby
    let activities: [Activity]
    
    @Environment(\.dismiss) private var dismiss
    
    private var forecast: MealForecast? {
        MealForecastEngine.forecast(from: activities, babyAgeInDays: baby.ageInDays)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if let forecast = forecast {
                    VStack(spacing: 24) {
                        // Next meal
                        forecastCard(
                            icon: "clock.badge.checkmark",
                            title: String(localized: "forecast_next_meal"),
                            value: forecast.nextIdealMealTime.formatted(date: .omitted, time: .shortened),
                            subtitle: forecast.nextMealFormatted,
                            color: forecast.isOverdue ? .red : .leonaOrange,
                            isHighlighted: true
                        )
                        
                        // Estimated volume
                        forecastCard(
                            icon: "cup.and.saucer.fill",
                            title: String(localized: "forecast_estimated_volume"),
                            value: "\(Int(forecast.estimatedVolumeML)) ml",
                            subtitle: String(localized: "forecast_with_bf \(Int(forecast.estimatedVolumeWithBreastfeedingML))"),
                            color: .orange
                        )
                        
                        // Average interval
                        forecastCard(
                            icon: "timer",
                            title: String(localized: "forecast_avg_interval"),
                            value: (forecast.averageIntervalMinutes * 60).hoursMinutesFormatted,
                            subtitle: String(localized: "forecast_between_meals"),
                            color: .blue
                        )
                        
                        // Max delay
                        forecastCard(
                            icon: "exclamationmark.triangle.fill",
                            title: String(localized: "forecast_max_delay"),
                            value: forecast.maxDelayTime.formatted(date: .omitted, time: .shortened),
                            subtitle: String(localized: "forecast_dont_exceed"),
                            color: .red
                        )
                        
                        // Confidence
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundStyle(.secondary)
                            Text(String(localized: "forecast_confidence"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(forecast.confidence.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(confidenceColor(forecast.confidence))
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Last feeding
                        if let lastTime = forecast.lastFeedingTime {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(.secondary)
                                Text(String(localized: "forecast_last_feeding"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(lastTime.smartDateTimeString)
                                    .font(.subheadline)
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()
                } else {
                    ContentUnavailableView(
                        String(localized: "forecast_unavailable"),
                        systemImage: "chart.bar.xaxis",
                        description: Text(String(localized: "forecast_need_more_data"))
                    )
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "meal_forecast"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "done")) { dismiss() }
                }
            }
        }
    }
    
    private func forecastCard(
        icon: String,
        title: String,
        value: String,
        subtitle: String,
        color: Color,
        isHighlighted: Bool = false
    ) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(isHighlighted ? color : .primary)
            
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .leonaCard()
    }
    
    private func confidenceColor(_ confidence: ForecastConfidence) -> Color {
        switch confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        }
    }
}
