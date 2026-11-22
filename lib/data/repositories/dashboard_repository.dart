/// The Home read model. One query pass, assembled with the domain rules.
library;

import '../../domain/dashboard.dart';
import '../../domain/rules/vaccination_due.dart';

abstract class DashboardRepository {
  Future<Dashboard> load({
    required DateTime now,
    int dueSoonWindowDays = defaultDueSoonWindowDays,
  });
}
