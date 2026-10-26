class GembaObservationStats {
  const GembaObservationStats({
    required this.total,
    required this.inProgress,
    required this.done,
    required this.assignedTotal,
    required this.assignedInProgress,
    required this.assignedDone,
    required this.createdByMe,
  });

  final int total;
  final int inProgress;
  final int done;
  final int assignedTotal;
  final int assignedInProgress;
  final int assignedDone;
  final int createdByMe;
}
