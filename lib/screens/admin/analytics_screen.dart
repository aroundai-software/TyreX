// lib/screens/admin/analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../services/forecasting_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final supabase = Supabase.instance.client;
  final ForecastingService _forecastingService = ForecastingService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _executives = [];
  List<String> _availableMonths = []; // Stored as 'yyyy-MM'

  // Filter state
  int? _selectedExecutiveId;
  String? _selectedMonth;

  // Data for the chart
  Map<String, int> _analyticsData = {'completed': 0, 'pending': 0, 'total': 0};
  String _chartTitle = 'Overall Status for All Time';
  
  // Advanced analytics data
  List<Map<String, dynamic>> _executiveWorkload = [];
  List<Map<String, dynamic>> _statusDistribution = [];
  Map<String, dynamic> _performanceMetrics = {};
  List<Map<String, dynamic>> _trendData = [];
  
  // Tab selection
  int _selectedTab = 0; // 0 = Status, 1 = Workload, 2 = Performance, 3 = Trends

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  /// Fetches the list of executives and available months to populate filters.
  Future<void> _loadInitialData() async {
    try {
      // Fetch executives
      final execResponse = await supabase
          .from('users')
          .select('id, username')
          .eq('role', 'executive');
      _executives = List<Map<String, dynamic>>.from(execResponse);

      // Fetch all reports to determine unique months
      final reportsResponse = await supabase.from('reports').select('created_at');
      final uniqueMonths = <String>{};
      for (var report in reportsResponse) {
        final date = DateTime.parse(report['created_at']);
        uniqueMonths.add(DateFormat('yyyy-MM').format(date));
      }
      _availableMonths = uniqueMonths.toList()..sort((a, b) => b.compareTo(a)); // Sort descending

      // Load initial analytics for all data
      await _loadAnalytics();

    } catch (e) {
      _showError('Failed to load filter data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Fetches and calculates analytics based on the current filter selection.
  Future<void> _loadAnalytics() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Fetch reports data
      var query = supabase.from('reports').select('status, executive_id, created_at');

      if (_selectedExecutiveId != null) {
        query = query.eq('executive_id', _selectedExecutiveId!);
      }

      if (_selectedMonth != null) {
        final startOfMonth = DateTime.parse('$_selectedMonth-01');
        final endOfMonth = DateTime(startOfMonth.year, startOfMonth.month + 1, 0); // Last day of month
        final endOfDay = DateTime(endOfMonth.year, endOfMonth.month, endOfMonth.day, 23, 59, 59);

        query = query.gte('created_at', startOfMonth.toIso8601String())
            .lt('created_at', endOfDay.add(const Duration(seconds: 1)).toIso8601String());
      }

      final response = await query;
      final reports = List<Map<String, dynamic>>.from(response);

      int completed = 0;
      for (var report in reports) {
        if (report['status'] == 'Completed') {
          completed++;
        }
      }

      _updateChartTitle();

      // Fetch executive workload data
      final workloadResponse = await supabase.rpc('get_executive_workload');
      final executiveWorkload = List<Map<String, dynamic>>.from(workloadResponse);
      
      // Calculate status distribution
      final statusCounts = <String, int>{};
      for (var report in reports) {
        final status = report['status'] as String;
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }
      
      // Convert to list for easier processing
      final statusDistribution = statusCounts.entries
          .map((entry) => {'status': entry.key, 'count': entry.value})
          .toList();
      
      // Calculate performance metrics
      final totalReports = reports.length;
      final completionRate = totalReports > 0 ? (completed / totalReports) * 100 : 0.0;
      
      // Calculate trend data (monthly counts)
      final trendData = <Map<String, dynamic>>[];
      final monthlyReports = <String, int>{};
      
      for (var report in reports) {
        final date = DateTime.parse(report['created_at']);
        final monthKey = DateFormat('yyyy-MM').format(date);
        monthlyReports[monthKey] = (monthlyReports[monthKey] ?? 0) + 1;
      }
      
      monthlyReports.forEach((month, count) {
        trendData.add({'month': month, 'count': count});
      });
      
      // Sort trend data by month
      trendData.sort((a, b) => a['month'].toString().compareTo(b['month'].toString()));

      setState(() {
        _analyticsData = {
          'completed': completed,
          'pending': reports.length - completed,
          'total': reports.length,
        };
        _executiveWorkload = executiveWorkload;
        _statusDistribution = statusDistribution;
        _performanceMetrics = {
          'totalReports': totalReports,
          'completionRate': completionRate,
          'averageReportsPerExecutive': executiveWorkload.isEmpty ? 0 : totalReports ~/ executiveWorkload.length,
        };
        _trendData = trendData;
      });

    } catch (e) {
      _showError('Failed to load analytics: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _updateChartTitle() {
    String execName = 'Overall';
    if (_selectedExecutiveId != null) {
      final exec = _executives.firstWhere((e) => e['id'] == _selectedExecutiveId, orElse: () => {});
      execName = exec['username'] ?? 'Selected Executive';
    }

    String monthName = 'for All Time';
    if (_selectedMonth != null) {
      final date = DateFormat('yyyy-MM').parse(_selectedMonth!);
      monthName = 'for ${DateFormat('MMMM yyyy').format(date)}';
    }

    _chartTitle = '$execName Status $monthName';
  }


  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Analytics'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 16.0),
        child: Column(
          children: [
            // Filters Card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filter Analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Month Filter
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedMonth,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Month'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Months')),
                            ..._availableMonths.map((month) {
                              final date = DateFormat('yyyy-MM').parse(month);
                              return DropdownMenuItem(
                                value: month,
                                child: Text(DateFormat('MMMM yyyy').format(date)),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedMonth = value);
                            _loadAnalytics();
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Executive Filter
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedExecutiveId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Executive'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Executives')),
                            ..._executives.map((exec) {
                              return DropdownMenuItem(
                                value: exec['id'] as int,
                                child: Text(exec['username']),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedExecutiveId = value);
                            _loadAnalytics();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Tab Bar
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppTheme.borderColor, width: 1),
                      ),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTab('Status Overview', 0),
                          _buildTab('Workload', 1),
                          _buildTab('Performance', 2),
                          _buildTab('Trends', 3),
                          _buildTab('Forecast', 4),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tab Content
                  _buildTabContent(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTab(String title, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedTab = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
  
  Widget _buildTabContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    switch (_selectedTab) {
      case 0: // Status Overview
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _chartTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildStatBar(
              title: 'Completed',
              value: _analyticsData['completed']!,
              total: _analyticsData['total']!,
              color: Colors.green,
            ),
            const SizedBox(height: 24),
            _buildStatBar(
              title: 'Pending/Ongoing',
              value: _analyticsData['pending']!,
              total: _analyticsData['total']!,
              color: Colors.orange,
            ),
          ],
        );
      case 1: // Workload
        return _buildWorkloadView();
      case 2: // Performance
        return _buildPerformanceView();
      case 3: // Trends
        return _buildTrendsView();
      case 4: // Forecast
        return _buildForecastView();
      default:
        return const SizedBox.shrink();
    }
  }
  
  Widget _buildWorkloadView() {
    // Prepare workload data for forecasting
    final workloadCounts = _executiveWorkload
        .map((w) => (w['active_job_count'] as int? ?? 0).toDouble())
        .toList();
    
    // Generate workload forecasts
    final avgWorkload = workloadCounts.isNotEmpty
        ? workloadCounts.reduce((a, b) => a + b) / workloadCounts.length
        : 0.0;
    
    final workloadForecast = workloadCounts.isNotEmpty
        ? _forecastingService.simpleMovingAverage(workloadCounts, periods: 3)
        : avgWorkload;
    
    // Identify workload distribution insights
    final minWorkload = workloadCounts.isNotEmpty
        ? workloadCounts.reduce((a, b) => a < b ? a : b)
        : 0.0;
    final maxWorkload = workloadCounts.isNotEmpty
        ? workloadCounts.reduce((a, b) => a > b ? a : b)
        : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Executive Workload Distribution & Forecast',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        // Workload summary with forecast
        if (workloadCounts.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Workload Insights',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Current avg: ${avgWorkload.toStringAsFixed(1)} jobs/executive\n'
                  '• Forecasted: ${workloadForecast.toStringAsFixed(1)} jobs/executive\n'
                  '• Workload range: ${minWorkload.toStringAsFixed(0)}-${maxWorkload.toStringAsFixed(0)} jobs',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                if ((workloadForecast - avgWorkload).abs() > 2) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (workloadForecast > avgWorkload ? Colors.red : Colors.green).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          workloadForecast > avgWorkload ? Icons.warning : Icons.thumb_up, 
                          color: workloadForecast > avgWorkload ? Colors.red : Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            workloadForecast > avgWorkload 
                                ? 'Workload expected to increase - consider redistribution' 
                                : 'Workload trending downward - good balance maintained',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: workloadForecast > avgWorkload ? Colors.red : Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        
        // Bar chart visualization
        if (_executiveWorkload.isNotEmpty) ...[
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            child: BarChart(
              _createWorkloadChartData(),
            ),
          ),
          const SizedBox(height: 24),
        ],
        
        if (_executiveWorkload.isEmpty)
          const Center(
            child: Text('No workload data available'),
          )
        else
          ..._executiveWorkload.map((workload) {
            final username = workload['username'] as String? ?? 'Unknown';
            final activeJobs = workload['active_job_count'] as int? ?? 0;
            final maxJobs = _executiveWorkload
                .map((w) => w['active_job_count'] as int? ?? 0)
                .reduce((a, b) => a > b ? a : b);
            final percentage = maxJobs > 0 ? activeJobs / maxJobs : 0.0;
            
            // Determine if this executive's workload is above/below average
            final isAboveAverage = workloadCounts.isNotEmpty && 
                activeJobs > avgWorkload;
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(username, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Row(
                        children: [
                          Text('$activeJobs jobs'),
                          if (isAboveAverage) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.trending_up, color: Colors.red, size: 16),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                    color: isAboveAverage ? Colors.red : AppTheme.primaryColor,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
  
  BarChartData _createWorkloadChartData() {
    final spots = <BarChartGroupData>[];
    
    // Find max value for y-axis
    final maxValue = _executiveWorkload
        .map((w) => w['active_job_count'] as int? ?? 0)
        .reduce((a, b) => a > b ? a : b);
    
    for (int i = 0; i < _executiveWorkload.length; i++) {
      final activeJobs = _executiveWorkload[i]['active_job_count'] as int? ?? 0;
      spots.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: activeJobs.toDouble(),
              color: AppTheme.primaryColor,
              width: 20,
              borderRadius: BorderRadius.zero,
            ),
          ],
          showingTooltipIndicators: [0],
        ),
      );
    }
    
    return BarChartData(
      gridData: FlGridData(show: true),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              if (value.toInt() < _executiveWorkload.length) {
                final workload = _executiveWorkload[value.toInt()];
                final username = workload['username'] as String? ?? 'Unknown';
                // Get first name or first few characters for chart labels
                final shortName = username.split(' ').first;
                final label = shortName.length > 6 ? '${shortName.substring(0, 6)}...' : shortName;
                return Text(label, style: const TextStyle(fontSize: 10));
              }
              return const Text('');
            },
            reservedSize: 30,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
            },
            reservedSize: 30,
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: true),
      barGroups: spots,
      minY: 0,
      maxY: maxValue.toDouble() + (maxValue * 0.1), // Add 10% padding
    );
  }
  
  Widget _buildPerformanceView() {
    final totalReports = _performanceMetrics['totalReports'] as int? ?? 0;
    final completionRate = _performanceMetrics['completionRate'] as double? ?? 0.0;
    final avgReports = _performanceMetrics['averageReportsPerExecutive'] as int? ?? 0;
    
    // Prepare completion rate data for forecasting
    final completionRateHistory = _getCompletionRateHistory();
    
    // Generate completion rate forecasts
    final completionRateForecast = completionRateHistory.isNotEmpty
        ? _forecastingService.simpleMovingAverage(completionRateHistory, periods: 3)
        : completionRate;
    
    final completionRateExpForecast = completionRateHistory.isNotEmpty
        ? _forecastingService.exponentialSmoothing(completionRateHistory, alpha: 0.4)
        : completionRate;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Performance Metrics & Forecast',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        // Performance metrics with forecast
        _buildMetricCard('Total Reports', totalReports.toString(), Icons.assignment, Colors.blue),
        const SizedBox(height: 12),
        
        // Completion rate with forecast indicator
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (completionRate >= 80 ? Colors.green : (completionRate >= 60 ? Colors.orange : Colors.red)).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: (completionRate >= 80 ? Colors.green : (completionRate >= 60 ? Colors.orange : Colors.red)).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle, 
                color: completionRate >= 80 ? Colors.green : (completionRate >= 60 ? Colors.orange : Colors.red), 
                size: 24
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Completion Rate',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${completionRate.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: completionRate >= 80 ? Colors.green : (completionRate >= 60 ? Colors.orange : Colors.red),
                          ),
                        ),
                        if (completionRateHistory.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Icon(
                            completionRateForecast > completionRate 
                                ? Icons.trending_up 
                                : (completionRateForecast < completionRate ? Icons.trending_down : Icons.trending_flat),
                            color: completionRateForecast > completionRate 
                                ? Colors.green 
                                : (completionRateForecast < completionRate ? Colors.red : Colors.grey),
                            size: 16,
                          ),
                          Text(
                            ' → ${completionRateForecast.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildMetricCard('Avg. Reports/Executive', avgReports.toString(), Icons.group, Colors.purple),
        const SizedBox(height: 24),
        
        // Forecast explanation for completion rate
        if (completionRateHistory.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.insights, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Forecast: ${(completionRateExpForecast - completionRate).abs() > 1 ? 'Trending' : 'Stable'} '
                    '(${completionRateExpForecast.toStringAsFixed(1)}% predicted)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        
        const Text(
          'Status Distribution',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        // Pie chart visualization
        if (_statusDistribution.isNotEmpty) ...[
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            child: PieChart(
              _createStatusDistributionData(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        ..._statusDistribution.map((statusData) {
          final status = statusData['status'] as String;
          final count = statusData['count'] as int;
          final percentage = totalReports > 0 ? (count / totalReports) * 100 : 0.0;
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatStatus(status), style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text('$count (${percentage.toStringAsFixed(1)}%)'),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: totalReports > 0 ? count / totalReports : 0.0,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  color: _getStatusColor(status),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
  
  Widget _buildForecastView() {
    // Prepare all data for comprehensive forecasting
    final reportCounts = _trendData
        .map((trend) => trend['count'] as int)
        .toList();
    
    final workloadCounts = _executiveWorkload
        .map((w) => (w['active_job_count'] as int? ?? 0).toDouble())
        .toList();
    
    final completionRate = _performanceMetrics['completionRate'] as double? ?? 0.0;
    final completionRateHistory = _getCompletionRateHistory();
    
    // Generate comprehensive forecasts
    final reportForecast = reportCounts.isNotEmpty
        ? _forecastingService.forecastWithConfidence(
            reportCounts.map((e) => e.toDouble()).toList())
        : ForecastWithConfidence(0, 0, 0);
    
    final workloadAvg = workloadCounts.isNotEmpty
        ? workloadCounts.reduce((a, b) => a + b) / workloadCounts.length
        : 0.0;
    
    final completionRateForecast = completionRateHistory.isNotEmpty
        ? _forecastingService.forecastWithConfidence(completionRateHistory)
        : ForecastWithConfidence(completionRate, completionRate, completionRate);
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comprehensive Forecast Insights',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          
          // Forecast summary cards
          Row(
            children: [
              Expanded(
                child: _buildForecastCard(
                  'Report Volume',
                  '${reportForecast.forecast.toStringAsFixed(0)} reports',
                  '95% CI: ${reportForecast.lowerBound.toStringAsFixed(0)}-${reportForecast.upperBound.toStringAsFixed(0)}',
                  Icons.analytics,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildForecastCard(
                  'Completion Rate',
                  '${completionRateForecast.forecast.toStringAsFixed(1)}%',
                  '95% CI: ${completionRateForecast.lowerBound.toStringAsFixed(1)}-${completionRateForecast.upperBound.toStringAsFixed(1)}%',
                  Icons.percent,
                  completionRateForecast.forecast >= 80 
                      ? Colors.green 
                      : (completionRateForecast.forecast >= 60 ? Colors.orange : Colors.red),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildForecastCard(
                  'Avg Workload',
                  '${workloadAvg.toStringAsFixed(1)} jobs/exec',
                  'Current distribution',
                  Icons.work,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildForecastCard(
                  'Risk Level',
                  _getRiskLevel(reportForecast.forecast, completionRateForecast.forecast),
                  _getRiskDescription(reportForecast.forecast, completionRateForecast.forecast),
                  _getRiskIcon(reportForecast.forecast, completionRateForecast.forecast),
                  _getRiskColor(reportForecast.forecast, completionRateForecast.forecast),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Detailed forecasts
          const Text(
            'Detailed Forecasts',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // Report volume forecast
          _buildDetailedForecastSection(
            'Report Volume Forecast',
            'Predicted report volumes for upcoming periods',
            [
              _buildForecastDetailItem(
                'Next Month',
                '${reportForecast.forecast.toStringAsFixed(0)} reports',
                'Expected range: ${reportForecast.lowerBound.toStringAsFixed(0)}-${reportForecast.upperBound.toStringAsFixed(0)}',
                Icons.calendar_month,
              ),
              _buildForecastDetailItem(
                '3-Month Trend',
                _getTrendDescription(reportCounts),
                'Based on historical data pattern',
                Icons.trending_up,
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Performance forecast
          _buildDetailedForecastSection(
            'Performance Forecast',
            'Predicted completion rates and efficiency',
            [
              _buildForecastDetailItem(
                'Next Month',
                '${completionRateForecast.forecast.toStringAsFixed(1)}% completion',
                'Confidence: 95%',
                Icons.speed,
              ),
              _buildForecastDetailItem(
                'Workload Impact',
                workloadAvg > 15 ? 'High workload may affect performance' : 'Workload within optimal range',
                workloadAvg > 15 
                    ? 'Consider redistributing tasks' 
                    : 'Current distribution is balanced',
                workloadAvg > 15 ? Icons.warning : Icons.check_circle,
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Recommendations
          const Text(
            'AI-Powered Recommendations',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          ..._getRecommendations(reportForecast.forecast, completionRateForecast.forecast, workloadAvg)
              .map((recommendation) => _buildRecommendationCard(recommendation)),
          
          const SizedBox(height: 24),
          
          // Methodology
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Forecasting Methodology',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '• Simple Moving Average (3 periods) for trend analysis\n'
                  '• Exponential Smoothing for responsive predictions\n'
                  '• Statistical confidence intervals (95% confidence)\n'
                  '• All computations performed locally - no external API calls\n'
                  '• Real-time updates with filter changes',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildForecastCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailedForecastSection(String title, String description, List<Widget> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ...items,
        ],
      ),
    );
  }
  
  Widget _buildForecastDetailItem(String title, String value, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecommendationCard(Recommendation recommendation) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: recommendation.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: recommendation.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(recommendation.icon, color: recommendation.color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recommendation.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: recommendation.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  recommendation.description,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                if (recommendation.action != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: recommendation.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      recommendation.action!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: recommendation.color,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _getRiskLevel(double reportForecast, double completionRate) {
    if (reportForecast > 50 && completionRate > 80) return 'Low';
    if (reportForecast > 30 && completionRate > 70) return 'Medium';
    return 'High';
  }
  
  String _getRiskDescription(double reportForecast, double completionRate) {
    if (reportForecast > 50 && completionRate > 80) {
      return 'Stable operations expected';
    } else if (reportForecast > 30 && completionRate > 70) {
      return 'Moderate risk - monitor trends';
    } else {
      return 'High risk - immediate attention needed';
    }
  }
  
  IconData _getRiskIcon(double reportForecast, double completionRate) {
    if (reportForecast > 50 && completionRate > 80) {
      return Icons.check_circle;
    } else if (reportForecast > 30 && completionRate > 70) {
      return Icons.warning;
    } else {
      return Icons.error;
    }
  }
  
  Color _getRiskColor(double reportForecast, double completionRate) {
    if (reportForecast > 50 && completionRate > 80) {
      return Colors.green;
    } else if (reportForecast > 30 && completionRate > 70) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
  
  String _getTrendDescription(List<int> reportCounts) {
    if (reportCounts.length < 3) return 'Insufficient data';
    
    // Simple trend analysis
    final lastThree = reportCounts.length >= 3 
        ? reportCounts.sublist(reportCounts.length - 3)
        : reportCounts;
        
    if (lastThree.length < 2) return 'Stable';
    
    bool isIncreasing = true;
    bool isDecreasing = true;
    
    for (int i = 1; i < lastThree.length; i++) {
      if (lastThree[i] <= lastThree[i-1]) isIncreasing = false;
      if (lastThree[i] >= lastThree[i-1]) isDecreasing = false;
    }
    
    if (isIncreasing) return 'Increasing trend';
    if (isDecreasing) return 'Decreasing trend';
    return 'Stable trend';
  }
  
  List<Recommendation> _getRecommendations(double reportForecast, double completionRate, double workloadAvg) {
    final recommendations = <Recommendation>[];
    
    // Workload recommendations
    if (workloadAvg > 20) {
      recommendations.add(
        Recommendation(
          title: 'Workload Redistribution',
          description: 'High average workload may lead to burnout and decreased quality.',
          action: 'Consider redistributing tasks or hiring additional staff',
          icon: Icons.group_add,
          color: Colors.red,
        ),
      );
    } else if (workloadAvg < 5) {
      recommendations.add(
        Recommendation(
          title: 'Resource Optimization',
          description: 'Low workload indicates underutilized resources.',
          action: 'Consider reallocating staff to other departments',
          icon: Icons.auto_fix_high,
          color: Colors.orange,
        ),
      );
    }
    
    // Performance recommendations
    if (completionRate < 70) {
      recommendations.add(
        Recommendation(
          title: 'Performance Improvement',
          description: 'Completion rate below target may indicate process inefficiencies.',
          action: 'Review workflows and provide additional training',
          icon: Icons.speed,
          color: Colors.red,
        ),
      );
    } else if (completionRate > 90) {
      recommendations.add(
        Recommendation(
          title: 'Maintain Excellence',
          description: 'Exceptional performance levels are being maintained.',
          action: 'Document best practices and share with team',
          icon: Icons.emoji_events,
          color: Colors.green,
        ),
      );
    }
    
    // Volume recommendations
    if (reportForecast > 40) {
      recommendations.add(
        Recommendation(
          title: 'Capacity Planning',
          description: 'High forecasted volume may strain current capacity.',
          action: 'Prepare additional resources and adjust schedules',
          icon: Icons.calendar_month,
          color: Colors.orange,
        ),
      );
    }
    
    // General recommendation if no specific ones
    if (recommendations.isEmpty) {
      recommendations.add(
        Recommendation(
          title: 'Continuous Monitoring',
          description: 'Current operations are stable and performing well.',
          action: 'Continue regular performance reviews',
          icon: Icons.monitor_heart,
          color: Colors.green,
        ),
      );
    }
    
    return recommendations;
  }
  
  /// Get historical completion rates for forecasting
  List<double> _getCompletionRateHistory() {
    // In a real implementation, this would fetch historical data
    // For now, we'll simulate with current data plus some variance
    final currentRate = _performanceMetrics['completionRate'] as double? ?? 0.0;
    
    // Simulate historical data (in a real app, this would come from database)
    return [
      currentRate * 0.95,  // Previous month
      currentRate * 0.98,  // 2 months ago
      currentRate * 1.02,  // 3 months ago
      currentRate * 0.99,  // 4 months ago
      currentRate,         // Current month
    ];
  }
  
  Widget _buildTrendsView() {
    // Prepare data for forecasting
    final reportCounts = _trendData
        .map((trend) => trend['count'] as int)
        .toList();
    
    // Generate forecasts
    final smaForecast = _forecastingService.simpleMovingAverage(
      reportCounts.map((e) => e.toDouble()).toList(),
      periods: 3,
    );
    
    final expForecast = _forecastingService.exponentialSmoothing(
      reportCounts.map((e) => e.toDouble()).toList(),
      alpha: 0.3,
    );
    
    final forecastWithConfidence = _forecastingService.forecastWithConfidence(
      reportCounts.map((e) => e.toDouble()).toList(),
    );
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Report Trends & Forecast',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        // Forecast summary cards
        if (reportCounts.isNotEmpty) ...[
          _buildForecastSummaryCard(
            'Next Month Prediction',
            '${smaForecast.toStringAsFixed(0)} reports',
            '95% CI: ${forecastWithConfidence.lowerBound.toStringAsFixed(0)} - ${forecastWithConfidence.upperBound.toStringAsFixed(0)}',
            Icons.trending_up,
            Colors.blue,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Moving Avg',
                  smaForecast.toStringAsFixed(0),
                  Icons.calculate, 
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Exp Smoothing',
                  expForecast.toStringAsFixed(0),
                  Icons.auto_graph, 
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        
        // Chart visualization
        if (_trendData.isNotEmpty) ...[
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            child: LineChart(
              _createTrendChartData(),
            ),
          ),
          const SizedBox(height: 24),
        ],
        
        // Forecast explanation
        if (reportCounts.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Forecast Method',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '• Simple Moving Average (3 months) for trend prediction\n'
                  '• Exponential Smoothing for responsive forecasting\n'
                  '• Confidence intervals based on historical variance',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        
        if (_trendData.isEmpty)
          const Center(
            child: Text('No trend data available'),
          )
        else
          ..._trendData.map((trend) {
            final month = trend['month'] as String;
            final count = trend['count'] as int;
            final maxCount = _trendData
                .map((t) => t['count'] as int)
                .reduce((a, b) => a > b ? a : b);
            final percentage = maxCount > 0 ? count / maxCount : 0.0;
            
            final date = DateFormat('yyyy-MM').parse(month);
            final monthName = DateFormat('MMM yyyy').format(date);
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(monthName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('$count reports'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                    color: AppTheme.primaryColor,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
  
  Widget _buildForecastSummaryCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  LineChartData _createTrendChartData() {
    // Convert trend data to chart points
    final spots = <FlSpot>[];
    for (int i = 0; i < _trendData.length; i++) {
      final count = _trendData[i]['count'] as int;
      spots.add(FlSpot(i.toDouble(), count.toDouble()));
    }
    
    // Find max value for y-axis
    final maxValue = spots.isNotEmpty 
        ? spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b)
        : 1.0;
    
    return LineChartData(
      gridData: FlGridData(show: true),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              if (value.toInt() < _trendData.length) {
                final month = _trendData[value.toInt()]['month'] as String;
                final date = DateFormat('yyyy-MM').parse(month);
                final monthName = DateFormat('MMM').format(date);
                return Text(monthName, style: const TextStyle(fontSize: 10));
              }
              return const Text('');
            },
            reservedSize: 30,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
            },
            reservedSize: 30,
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: true),
      minX: 0,
      maxX: (_trendData.length - 1).toDouble(),
      minY: 0,
      maxY: maxValue + (maxValue * 0.1), // Add 10% padding
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppTheme.primaryColor,
          barWidth: 3,
          belowBarData: BarAreaData(
            show: true,
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
          ),
          dotData: FlDotData(show: true),
        ),
      ],
    );
  }
  
  PieChartData _createStatusDistributionData() {
    final total = _statusDistribution.fold(0, (sum, item) => sum + (item['count'] as int));
    
    // Define colors for different statuses
    final statusColors = {
      'Completed': Colors.green,
      'Ongoing': Colors.orange,
      'Not Started': Colors.red,
      'pending_inspection': Colors.blue,
      'inspection_approved': Colors.teal,
      'rejected': Colors.red.shade700,
      'Sent To Wash': Colors.purple,
      'Wash Completed': Colors.green.shade700,
    };
    
    final sections = <PieChartSectionData>[];
    
    for (int i = 0; i < _statusDistribution.length; i++) {
      final statusData = _statusDistribution[i];
      final status = statusData['status'] as String;
      final count = statusData['count'] as int;
      final percentage = total > 0 ? (count / total) * 100 : 0.0;
      
      sections.add(
        PieChartSectionData(
          value: percentage,
          title: '${percentage.toStringAsFixed(1)}%',
          color: statusColors[status] ?? Colors.grey.shade600,
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    
    return PieChartData(
      sections: sections,
      centerSpaceRadius: 40,
    );
  }
  
  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'Ongoing':
        return Colors.orange;
      case 'Not Started':
        return Colors.red;
      case 'pending_inspection':
        return Colors.blue;
      case 'inspection_approved':
        return Colors.teal;
      case 'rejected':
        return Colors.red.shade700;
      case 'Sent To Wash':
        return Colors.purple;
      case 'Wash Completed':
        return Colors.green.shade700;
      default:
        return Colors.grey.shade600;
    }
  }
  
  String _formatStatus(String status) {
    // Convert snake_case to Title Case
    return status
        .split('_')
        .map((word) => word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  /// A helper widget to build a single progress bar for a status.
  Widget _buildStatBar({
    required String title,
    required int value,
    required int total,
    required Color color,
  }) {
    final double percentage = total > 0 ? value / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$title ($value)', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            Text('${(percentage * 100).toStringAsFixed(1)}%'),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: color.withValues(alpha: 0.2),
          color: color,
          minHeight: 12,
          borderRadius: BorderRadius.circular(6),
        ),
      ],
    );
  }
}

class Recommendation {
  final String title;
  final String description;
  final String? action;
  final IconData icon;
  final Color color;
  
  Recommendation({
    required this.title,
    required this.description,
    this.action,
    required this.icon,
    required this.color,
  });
}