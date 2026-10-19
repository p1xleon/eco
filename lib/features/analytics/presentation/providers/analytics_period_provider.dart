import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/analytics_aggregation.dart';

final analyticsPeriodProvider = StateProvider<AnalyticsPeriod>(
  (ref) => AnalyticsPeriod.thisMonth,
);
