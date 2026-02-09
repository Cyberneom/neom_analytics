# neom_analytics

Analytics and charting module for the Open Neom ecosystem.

neom_analytics provides reusable chart components and data visualization tools for tracking consumption metrics, engagement statistics, and performance analytics across NEOM applications.

## Features & Components

### Chart Types

#### Yearly Line Chart
- **12-month visualization**: Monthly data trends
- **Gradient area fill**: Visually appealing data representation
- **Average mode toggle**: Compare individual vs average values
- **Smart Y-axis scaling**: Automatic K/M formatting for large numbers

#### Weekly Bar Chart
- **7-day visualization**: Daily breakdown for the week
- **Touch interactions**: Highlight and tooltip on tap
- **Animated transitions**: Smooth state changes

#### Pie Chart Integration
- **Category distribution**: Visual breakdown of data categories
- **Customizable colors**: Theme-aware color schemes

### Analytics Features
- **CSV Export**: Data export capabilities
- **Animated transitions**: Smooth chart animations with flutter_animate
- **Responsive design**: Adapts to different screen sizes

## Architecture

```
lib/
├── ui/
│   └── charts/
│       ├── yearly_line_chart.dart
│       └── weekly_bar_chart.dart
└── neom_analytics.dart
```

## Dependencies

```yaml
dependencies:
  neom_core: ^2.0.0       # Core services and models
  neom_commons: ^1.0.0    # Shared UI components
  fl_chart: ^1.1.1        # Flexible charting library
  csv: ^6.0.0             # CSV data handling
  flutter_animate: ^4.5.2 # Animation utilities
  pie_chart: ^5.4.0       # Pie chart widget
```

## Usage

### Yearly Line Chart

```dart
import 'package:neom_analytics/ui/charts/yearly_line_chart.dart';

// Monthly data: month number (1-12) -> value
Map<int, int> monthlyData = {
  1: 1200,  // January
  2: 1500,  // February
  3: 1800,  // March
  // ... etc
};

YearlyLineChart(
  monthlyValues: monthlyData,
  xTitle: 'Mes',
  yTitle: 'Casete',
  yTitlesInterval: 5,
)
```

### Weekly Bar Chart

```dart
import 'package:neom_analytics/ui/charts/weekly_bar_chart.dart';

// Weekly data: day number (1-7) -> value
Map<int, int> weeklyData = {
  1: 120,  // Monday
  2: 150,  // Tuesday
  3: 180,  // Wednesday
  // ... etc
};

WeeklyBarChart(
  weeklyValues: weeklyData,
  xTitle: 'Dia',
  yTitle: 'Minutos',
)
```

## Y-Axis Formatting

The charts automatically format large numbers:
- Values >= 1,000,000: Display as "XM" (millions)
- Values >= 1,000: Display as "XK" (thousands)
- Values < 1,000: Display as-is

## ROADMAP 2026

### Q1 2026 - Enhanced Chart Types
- [ ] Stacked bar charts for multi-category comparison
- [ ] Radar/spider charts for multi-dimensional data
- [ ] Heatmap calendar view
- [ ] Sparkline mini-charts

### Q2 2026 - Real-time Analytics
- [ ] Live data streaming support
- [ ] WebSocket integration for dashboards
- [ ] Auto-refresh intervals
- [ ] Data buffering and aggregation

### Q3 2026 - Export & Sharing
- [ ] PDF report generation
- [ ] Image export (PNG, SVG)
- [ ] Shareable chart links
- [ ] Email report scheduling

### Q4 2026 - Advanced Features
- [ ] Predictive trend lines
- [ ] Anomaly detection highlights
- [ ] Goal/target markers
- [ ] Comparison overlays (YoY, MoM)

## Integration with NEOM Modules

neom_analytics is used by:
- **neom_casete**: Audio consumption tracking and revenue analytics
- **neom_nupale**: Reading consumption and engagement metrics
- **neom_bands**: Band performance and fan engagement stats

## Contributing

We welcome contributions! If you're interested in data visualization, charting libraries, or analytics dashboards, your help can strengthen the analytics capabilities.

## License

This project is licensed under the Apache License, Version 2.0, January 2004. See the LICENSE file for details.
