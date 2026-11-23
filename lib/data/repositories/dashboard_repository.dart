/// The Home read model. One query pass, assembled with the domain rules.
library;

import '../../domain/dashboard.dart';
import '../../domain/rules/vaccination_due.dart';

abstract class DashboardRepository {
  /// [today] is the household's calendar day; the due rule and the last-visit
  /// label are dates, not instants. Callers pass the local day so Home and the
  /// pet page can never disagree by a timezone offset.
  Future<Dashboard> load({
    required DateTime now,
    DateTime? today,
    int dueSoonWindowDays = defaultDueSoonWindowDays,
  });
}
