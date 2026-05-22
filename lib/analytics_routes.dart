import 'package:neom_core/ui/deferred_loader.dart';
import 'package:neom_core/utils/constants/app_route_constants.dart';
import 'package:sint/sint.dart';

import 'ui/analytics_page.dart' deferred as analytics;
import 'ui/error_monitor_page.dart' deferred as errorMonitor;
import 'ui/flow_monitor_page.dart' deferred as flowMonitor;

class AnalyticsRoutes {

  static final List<SintPage<dynamic>> routes = [
    SintPage(
      name: AppRouteConstants.analytics,
      page: () => DeferredLoader(analytics.loadLibrary, () => analytics.AnalyticsPage()),
      transition: Transition.zoom,
    ),
    SintPage(
      name: AppRouteConstants.errorMonitor,
      page: () => DeferredLoader(errorMonitor.loadLibrary, () => errorMonitor.ErrorMonitorPage()),
      transition: Transition.rightToLeftWithFade,
    ),
    SintPage(
      name: AppRouteConstants.flowMonitor,
      page: () => DeferredLoader(flowMonitor.loadLibrary, () => flowMonitor.FlowMonitorPage()),
      transition: Transition.rightToLeftWithFade,
    ),
  ];

}
