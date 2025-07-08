import 'package:get/get.dart';
import 'package:neom_core/utils/constants/app_route_constants.dart';
import '../analytics/ui/analytics_page.dart';
import '../media/media_fullscreen_page.dart';
import 'ui/analytics_page.dart';
import 'ui/previous_version_page.dart';
import 'ui/splash_page.dart';
import 'ui/under_construction_page.dart';

class CommonRoutes {

  static final List<GetPage<dynamic>> routes = [
    GetPage(
      name: AppRouteConstants.analytics,
      page: () => const AnalyticsPage(),
      transition: Transition.zoom,
    ),
  ];

}
