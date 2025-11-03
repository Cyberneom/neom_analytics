import 'package:get/get.dart';
import 'package:neom_core/utils/constants/app_route_constants.dart';

import 'ui/analytics_page.dart';

class AnalyticsRoutes {

  static final List<GetPage<dynamic>> routes = [
    GetPage(
      name: AppRouteConstants.analytics,
      page: () => const AnalyticsPage(),
      transition: Transition.zoom,
    ),
  ];

}
