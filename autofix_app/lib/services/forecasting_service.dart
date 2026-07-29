// lib/services/forecasting_service.dart
import 'dart:math';

class ForecastingService {
  /// Simple moving average forecast
  /// Predicts next value based on average of last n periods
  double simpleMovingAverage(List<double> data, {int periods = 3}) {
    if (data.isEmpty) return 0.0;
    if (data.length < periods) return data.last;
    
    double sum = 0.0;
    for (int i = data.length - periods; i < data.length; i++) {
      sum += data[i];
    }
    return sum / periods;
  }
  
  /// Exponential smoothing forecast
  /// More responsive to recent changes
  double exponentialSmoothing(List<double> data, {double alpha = 0.3}) {
    if (data.isEmpty) return 0.0;
    if (data.length == 1) return data[0];
    
    double forecast = data[0];
    for (int i = 1; i < data.length; i++) {
      forecast = alpha * data[i] + (1 - alpha) * forecast;
    }
    return forecast;
  }
  
  /// Linear trend forecast
  /// Predicts future values based on linear trend
  double linearTrendForecast(List<Map<String, dynamic>> timeSeriesData) {
    if (timeSeriesData.length < 2) {
      return timeSeriesData.isNotEmpty ? (timeSeriesData.last['value'] as double? ?? 0.0) : 0.0;
    }
    
    // Simple linear regression: y = a + bx
    double sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;
    int n = timeSeriesData.length;
    
    for (int i = 0; i < n; i++) {
      double x = i.toDouble();
      double y = timeSeriesData[i]['value'] as double? ?? 0.0;
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumXX += x * x;
    }
    
    double slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
    double intercept = (sumY - slope * sumX) / n;
    
    // Predict next value (n+1)
    return intercept + slope * n;
  }
  
  /// Seasonal adjustment forecast
  /// Accounts for recurring patterns
  double seasonalForecast(List<double> data, {int seasonLength = 12}) {
    if (data.length < seasonLength) {
      return simpleMovingAverage(data);
    }
    
    // Calculate seasonal indices
    List<double> seasonalIndices = List.filled(seasonLength, 0.0);
    int fullSeasons = (data.length / seasonLength).floor();
    
    if (fullSeasons == 0) {
      return simpleMovingAverage(data);
    }
    
    // Calculate average for each season period
    for (int i = 0; i < seasonLength; i++) {
      double sum = 0.0;
      int count = 0;
      for (int j = 0; j < fullSeasons; j++) {
        int index = j * seasonLength + i;
        if (index < data.length) {
          sum += data[index];
          count++;
        }
      }
      seasonalIndices[i] = count > 0 ? sum / count : 0.0;
    }
    
    // Use the most recent seasonal pattern
    int nextSeasonIndex = data.length % seasonLength;
    return seasonalIndices[nextSeasonIndex];
  }
  
  /// Confidence interval for forecasts
  ForecastWithConfidence forecastWithConfidence(List<double> data) {
    double forecast = simpleMovingAverage(data);
    
    if (data.length < 2) {
      return ForecastWithConfidence(forecast, forecast * 0.9, forecast * 1.1);
    }
    
    // Calculate standard deviation
    double mean = data.reduce((a, b) => a + b) / data.length;
    double variance = data.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / (data.length - 1);
    double stdDev = sqrt(variance);
    
    // 95% confidence interval (roughly ±2 standard deviations)
    double lowerBound = max(0, forecast - 2 * stdDev);
    double upperBound = forecast + 2 * stdDev;
    
    return ForecastWithConfidence(forecast, lowerBound, upperBound);
  }
}

class ForecastWithConfidence {
  final double forecast;
  final double lowerBound;
  final double upperBound;
  
  ForecastWithConfidence(this.forecast, this.lowerBound, this.upperBound);
  
  @override
  String toString() => 'Forecast: $forecast (95% CI: $lowerBound - $upperBound)';
}
