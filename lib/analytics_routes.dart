import 'package:neom_core/utils/constants/app_route_constants.dart';
import 'package:sint/sint.dart';

import 'ui/analytics_page.dart';
import 'ui/error_monitor_page.dart';
import 'ui/flow_monitor_page.dart';

class AnalyticsRoutes {

  static final List<SintPage<dynamic>> routes = [
    SintPage(
      name: AppRouteConstants.analytics,
      page: () => const AnalyticsPage(),
      transition: Transition.zoom,
    ),
    SintPage(
      name: AppRouteConstants.errorMonitor,
      page: () => const ErrorMonitorPage(),
      transition: Transition.rightToLeftWithFade,
    ),
    SintPage(
      name: AppRouteConstants.flowMonitor,
      page: () => const FlowMonitorPage(),
      transition: Transition.rightToLeftWithFade,
    ),
  ];

}
