class GembaObservationStatus {
  GembaObservationStatus._();

  static const inProgress = 'In-progress';
  static const done = 'Done';

  static String normalize(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    if (value == 'done' || value == 'closed') return done;
    if (value == 'in-progress' ||
        value == 'in progress' ||
        value == 'open' ||
        value == 'in_progress') {
      return inProgress;
    }
    return inProgress;
  }

  static bool isDone(String status) => normalize(status) == done;
}

enum GembaReportStatusFilter {
  all,
  open,
  closed;

  String get label => switch (this) {
        GembaReportStatusFilter.all => 'All',
        GembaReportStatusFilter.open => 'Open',
        GembaReportStatusFilter.closed => 'Closed',
      };

  String get reportTitle => switch (this) {
        GembaReportStatusFilter.all => 'Observations Report',
        GembaReportStatusFilter.open => 'Open Observations Report',
        GembaReportStatusFilter.closed => 'Closed Observations Report',
      };

  String get emptyMessage => switch (this) {
        GembaReportStatusFilter.all =>
          'No observations found for the selected filters.',
        GembaReportStatusFilter.open =>
          'No open observations found for the selected filters.',
        GembaReportStatusFilter.closed =>
          'No closed observations found for the selected filters.',
      };
}
