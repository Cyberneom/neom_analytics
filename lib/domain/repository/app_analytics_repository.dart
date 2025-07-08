import 'dart:async';
import 'package:neom_core/domain/model/app_coupon.dart';
import '../model/user_locations.dart';

abstract class AppAnalyticsRepository {

  Future<List<UserLocations>> getUserLocations();
  Future<Map<String, AppCoupon>> getUserAnalytics();
  Future<AppCoupon> getAnalyticsByType(String couponCode);
  Future<void> setUserLocations();

}
