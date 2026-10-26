import 'package:flutter/material.dart';
import '../../theme/gemba_colors.dart';

import '../../data/gemba_demo_data.dart';
import '../../data/gemba_org_data.dart';
import '../../models/gemba_user.dart';
import '../../widgets/gemba_location_filter_panel.dart';
import '../../widgets/gemba_searchable_picker.dart';
import '../../models/gemba_observation_stats.dart';
import '../../models/gemba_observation_status.dart';
import '../../models/gemba_observation.dart';
import '../../services/gemba_observations_service.dart';
import '../../services/gemba_session_service.dart';
import 'gemba_observation_detail_screen.dart';

/// Gemba observations list with All / Assigned / In-progress / Done filters.
class GembaObservationsScreen extends StatefulWidget {
  const GembaObservationsScreen({
    super.key,
    this.filterNotifier,
  });

  final ValueNotifier<GembaObservationFilter>? filterNotifier;

  @override
  State<GembaObservationsScreen> createState() =>
      _GembaObservationsScreenState();
}

class _GembaObservationsScreenState extends State<GembaObservationsScreen> {
  final _service = GembaObservationsService.instance;

  late GembaObservationFilter _filter;
  String? _currentEmployeeNumber;
  GembaUser? _user;
  String? _bu;
  String? _section;
  String? _category;
  bool _loading = true;
  String? _error;

  bool get _isAdmin => _user?.isAdmin ?? false;

  bool get _hasFilters =>
      (_bu?.isNotEmpty ?? false) ||
      (_section?.isNotEmpty ?? false) ||
      (_category?.isNotEmpty ?? false);

  List<String> get _sections {
    if (_bu == null || _bu!.isEmpty) return const [];
    return GembaOrgData.pclBuSections[_bu!] ?? const [];
  }

  List<GembaPickerOption> get _buOptions => [
        for (final bu in GembaOrgData.pclBuSfDivisionIds.keys)
          GembaPickerOption(value: bu, title: bu),
      ];

  List<GembaPickerOption> get _sectionOptions => [
        for (final section in _sections)
          GembaPickerOption(value: section, title: section),
      ];

  List<GembaPickerOption> get _categoryOptions => [
        for (final category in GembaOrgData.observationCategories)
          GembaPickerOption(value: category, title: category),
      ];

  String? get _filterSummary => _hasFilters
      ? [
          if (_bu != null && _bu!.isNotEmpty) _bu!,
          if (_section != null && _section!.isNotEmpty) _section!,
          if (_category != null && _category!.isNotEmpty) _category!,
        ].join(' / ')
      : null;

  @override
  void initState() {
    super.initState();
    _filter = widget.filterNotifier?.value ?? GembaObservationFilter.all;
    widget.filterNotifier?.addListener(_onExternalFilterChanged);
    _service.addListener(_onObservationsChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    widget.filterNotifier?.removeListener(_onExternalFilterChanged);
    _service.removeListener(_onObservationsChanged);
    super.dispose();
  }

  void _onExternalFilterChanged() {
    if (!mounted || widget.filterNotifier == null) return;
    setState(() => _filter = widget.filterNotifier!.value);
  }

  void _setFilter(GembaObservationFilter value) {
    setState(() => _filter = value);
    widget.filterNotifier?.value = value;
  }

  void _onObservationsChanged() {
    if (!mounted) return;
    setState(() {
      if (_service.isLoaded) _loading = false;
      _error = _service.lastError;
    });
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await GembaSessionService.instance.loadSession();
      await _service.reload();
      if (!mounted) return;
      setState(() {
        _user = session?.user;
        _currentEmployeeNumber = session?.user.employeeNumber;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _bu = null;
      _section = null;
      _category = null;
    });
  }

  void _onBuChanged(String bu) {
    setState(() {
      _bu = bu;
      _section = null;
    });
  }

  void _onSectionChanged(String section) {
    setState(() => _section = section);
  }

  void _onCategoryChanged(String category) {
    setState(() => _category = category);
  }

  List<GembaObservation> get _visibleItems => _service.filtered(
        filter: _filter,
        currentEmployeeNumber: _currentEmployeeNumber,
        bu: _bu,
        section: _section,
        category: _category,
      );

  GembaObservationStats get _stats => _service.stats(
        currentEmployeeNumber: _currentEmployeeNumber,
        bu: _bu,
        section: _section,
        category: _category,
      );

  int _countForFilter(GembaObservationFilter filter) {
    return _service
        .filtered(
          filter: filter,
          currentEmployeeNumber: _currentEmployeeNumber,
          bu: _bu,
          section: _section,
          category: _category,
        )
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final items = _visibleItems;
    final stats = _stats;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: GembaColors.scaffoldGradient,
        ),
      ),
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: GembaColors.brandPrimary),
            )
          : RefreshIndicator(
              color: GembaColors.brandPrimary,
              onRefresh: _bootstrap,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  _ObservationsHeader(
                    visibleCount: items.length,
                    totalCount: stats.total,
                    filter: _filter,
                    isAdmin: _isAdmin,
                    filterSummary: _filterSummary,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    _ErrorBanner(error: _error!, onRetry: _bootstrap),
                  ],
                  const SizedBox(height: 18),
                  GembaLocationFilterPanel(
                    bu: _bu,
                    section: _section,
                    category: _category,
                    buOptions: _buOptions,
                    sectionOptions: _sectionOptions,
                    categoryOptions: _categoryOptions,
                    sectionsEnabled: _bu != null && _bu!.isNotEmpty,
                    hasFilters: _hasFilters,
                    filterSummary: _filterSummary,
                    onBuSelected: _onBuChanged,
                    onSectionSelected: _onSectionChanged,
                    onCategorySelected: _onCategoryChanged,
                    onClear: _clearFilters,
                  ),
                  const SizedBox(height: 18),
                  _FilterBar(
                    selected: _filter,
                    onSelected: _setFilter,
                    countFor: _countForFilter,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(
                        '${items.length} observation${items.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: GembaColors.ink,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const Spacer(),
                      if (!_loading && _error == null)
                        Text(
                          _isAdmin
                              ? '${stats.total} total'
                              : '${stats.total} yours',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: GembaColors.slate,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (items.isEmpty)
                    _EmptyState(
                      filter: _filter,
                      employeeNumber: _currentEmployeeNumber,
                    )
                  else
                    for (final item in items) ...[
                      _ObservationCard(
                        item: item,
                        isMine: item.isAssignedTo(
                          _currentEmployeeNumber ?? '',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
    );
  }
}

class _ObservationsHeader extends StatelessWidget {
  const _ObservationsHeader({
    required this.visibleCount,
    required this.totalCount,
    required this.filter,
    required this.isAdmin,
    this.filterSummary,
  });

  final int visibleCount;
  final int totalCount;
  final GembaObservationFilter filter;
  final bool isAdmin;
  final String? filterSummary;

  String get _subtitle {
    if (filterSummary != null && filterSummary!.isNotEmpty) {
      return filterSummary!;
    }
    switch (filter) {
      case GembaObservationFilter.assigned:
        return isAdmin ? 'Assigned observations' : 'Assigned to you';
      case GembaObservationFilter.assignedInProgress:
        return isAdmin ? 'Assigned — in progress' : 'Your action items';
      case GembaObservationFilter.inProgress:
        return 'Open observations';
      case GembaObservationFilter.done:
        return 'Completed work';
      case GembaObservationFilter.all:
        return isAdmin ? 'All shop-floor findings' : 'Your observations';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: GembaColors.headerGradientSimple,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: GembaColors.brandPrimary.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Observations',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                Text(
                  '$visibleCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'of $totalCount',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.onSelected,
    required this.countFor,
  });

  final GembaObservationFilter selected;
  final ValueChanged<GembaObservationFilter> onSelected;
  final int Function(GembaObservationFilter) countFor;

  static const _filters = [
    (
      filter: GembaObservationFilter.all,
      label: 'All',
      icon: Icons.grid_view_rounded,
    ),
    (
      filter: GembaObservationFilter.assignedInProgress,
      label: 'Action',
      icon: Icons.playlist_add_check_rounded,
    ),
    (
      filter: GembaObservationFilter.assigned,
      label: 'Assigned',
      icon: Icons.assignment_ind_outlined,
    ),
    (
      filter: GembaObservationFilter.inProgress,
      label: 'In progress',
      icon: Icons.pending_actions_outlined,
    ),
    (
      filter: GembaObservationFilter.done,
      label: 'Done',
      icon: Icons.task_alt_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final entry in _filters) ...[
            _FilterPill(
              label: entry.label,
              icon: entry.icon,
              count: countFor(entry.filter),
              selected: selected == entry.filter,
              onTap: () => onSelected(entry.filter),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? GembaColors.brandPrimary : Colors.white,
      borderRadius: BorderRadius.circular(999),
      elevation: selected ? 0 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? GembaColors.brandPrimary : GembaColors.border,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: GembaColors.brandPrimary.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : GembaColors.brandPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : GembaColors.ink,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.22)
                        : GembaColors.brandTint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : GembaColors.brandPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error, required this.onRetry});

  final String error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud_off_outlined, size: 18, color: Color(0xFFB91C1C)),
              SizedBox(width: 8),
              Text(
                'Could not load observations',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB91C1C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            error,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF991B1B),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFB91C1C),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.filter,
    required this.employeeNumber,
  });

  final GembaObservationFilter filter;
  final String? employeeNumber;

  @override
  Widget build(BuildContext context) {
    final mine = GembaDemoData.normalizeEmployeeNumber(employeeNumber);

    final title = switch (filter) {
      GembaObservationFilter.assigned => 'No observations assigned to you',
      GembaObservationFilter.assignedInProgress => 'Nothing needs your action',
      GembaObservationFilter.inProgress => 'No in-progress observations',
      GembaObservationFilter.done => 'No completed observations yet',
      GembaObservationFilter.all => 'No observations yet',
    };

    final message = switch (filter) {
      GembaObservationFilter.assigned => mine.isEmpty
          ? 'Your employee number is not available in the session.'
          : 'Observations assigned to $mine will appear here.',
      GembaObservationFilter.assignedInProgress => mine.isEmpty
          ? 'Your employee number is not available in the session.'
          : 'In-progress items assigned to you will show here.',
      GembaObservationFilter.inProgress =>
        'Open observations will appear here after they are created.',
      GembaObservationFilter.done =>
        'Observations marked as Done will appear here.',
      GembaObservationFilter.all =>
        'Create a new observation from the Add Observation tab.',
    };

    final icon = switch (filter) {
      GembaObservationFilter.assigned => Icons.assignment_ind_outlined,
      GembaObservationFilter.assignedInProgress =>
        Icons.playlist_add_check_rounded,
      GembaObservationFilter.inProgress => Icons.pending_actions_outlined,
      GembaObservationFilter.done => Icons.task_alt_outlined,
      GembaObservationFilter.all => Icons.inbox_outlined,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GembaColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  GembaColors.brandTint,
                  GembaColors.brandLight.withValues(alpha: 0.35),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: GembaColors.brandPrimary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: GembaColors.slate,
              height: 1.45,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ObservationCard extends StatelessWidget {
  const _ObservationCard({
    required this.item,
    required this.isMine,
  });

  final GembaObservation item;
  final bool isMine;

  bool get _isDone => GembaObservationStatus.isDone(item.status);

  Color get _statusColor =>
      _isDone ? const Color(0xFF059669) : const Color(0xFFD97706);

  String get _statusLabel => GembaObservationStatus.normalize(item.status);

  String get _assigneeLabel {
    final name = item.assignedEmployeeName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return item.assignedEmployeeNumber;
  }

  String get _remarksPreview {
    final text = item.remarks.trim();
    if (text.isEmpty) return 'No remarks';
    return text.length > 90 ? '${text.substring(0, 90)}…' : text;
  }

  String _formatDate(DateTime date) {
    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => GembaObservationDetailScreen(
                observationId: item.id,
              ),
            ),
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GembaColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 4, color: _statusColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _MetaChip(
                                    icon: Icons.category_outlined,
                                    label: item.category,
                                  ),
                                  if (isMine && !_isDone)
                                    const _MetaChip(
                                      icon: Icons.person_pin_circle_outlined,
                                      label: 'Assigned to you',
                                      highlight: true,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusBadge(
                              label: _statusLabel,
                              color: _statusColor,
                            ),
                          ],
                        ),
                          const SizedBox(height: 10),
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.place_outlined,
                                size: 15,
                                color: GembaColors.slate,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  item.section?.trim().isNotEmpty == true
                                      ? item.section!
                                      : item.location,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: GembaColors.slate,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _remarksPreview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              height: 1.35,
                              fontStyle: item.remarks.trim().isEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.person_outline_rounded,
                                size: 15,
                                color: GembaColors.brandPrimary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _assigneeLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: GembaColors.ink,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.schedule_outlined,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(item.createdAt),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlight ? GembaColors.brandTint : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight ? GembaColors.border : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: highlight ? GembaColors.brandPrimary : GembaColors.slate,
          ),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: highlight ? GembaColors.brandPrimary : GembaColors.slate,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
