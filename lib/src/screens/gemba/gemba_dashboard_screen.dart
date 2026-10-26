import 'package:flutter/material.dart';
import '../../theme/gemba_colors.dart';

import '../../data/gemba_org_data.dart';
import '../../models/gemba_observation_stats.dart';
import '../../models/gemba_user.dart';
import '../../services/gemba_observations_service.dart';
import '../../services/gemba_session_service.dart';
import '../../widgets/gemba_location_filter_panel.dart';
import '../../widgets/gemba_searchable_picker.dart';

class GembaDashboardScreen extends StatefulWidget {
  const GembaDashboardScreen({
    super.key,
    required this.onNavigateToObservations,
    required this.onNavigateToAdd,
  });

  final ValueChanged<GembaObservationFilter> onNavigateToObservations;
  final VoidCallback onNavigateToAdd;

  @override
  State<GembaDashboardScreen> createState() => _GembaDashboardScreenState();
}

class _GembaDashboardScreenState extends State<GembaDashboardScreen> {
  

  final _service = GembaObservationsService.instance;

  GembaUser? _user;
  GembaObservationStats? _stats;
  bool _loading = true;
  String? _error;
  String? _bu;
  String? _section;
  String? _category;

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

  GembaObservationStats _computeStats() {
    return _service.stats(
      currentEmployeeNumber: _user?.employeeNumber,
      bu: _bu,
      section: _section,
      category: _category,
    );
  }

  void _clearFilters() {
    setState(() {
      _bu = null;
      _section = null;
      _category = null;
      _stats = _computeStats();
    });
  }

  void _onBuChanged(String bu) {
    setState(() {
      _bu = bu;
      _section = null;
      _stats = _computeStats();
    });
  }

  void _onSectionChanged(String section) {
    setState(() {
      _section = section;
      _stats = _computeStats();
    });
  }

  void _onCategoryChanged(String category) {
    setState(() {
      _category = category;
      _stats = _computeStats();
    });
  }

  @override
  void initState() {
    super.initState();
    _service.addListener(_refresh);
    _load();
  }

  @override
  void dispose() {
    _service.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _stats = _computeStats();
      _error = _service.lastError;
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final session = await GembaSessionService.instance.loadSession();
    try {
      await _service.reload();
      if (!mounted) return;
      setState(() {
        _user = session?.user;
        _stats = _computeStats();
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _user = session?.user;
        _stats = _computeStats();
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _stats == null) {
      return const Center(
        child: CircularProgressIndicator(color: GembaColors.brandPrimary),
      );
    }

    final stats = _stats!;
    final firstName = _firstName(_user?.name);
    final filterSummary = _hasFilters
        ? [
            if (_bu != null && _bu!.isNotEmpty) _bu!,
            if (_section != null && _section!.isNotEmpty) _section!,
            if (_category != null && _category!.isNotEmpty) _category!,
          ].join(' / ')
        : null;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: GembaColors.scaffoldGradient,
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _WelcomeHeader(firstName: firstName, employeeNumber: _user?.employeeNumber),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Could not refresh counts from server',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB91C1C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF991B1B),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            GembaLocationFilterPanel(
              bu: _bu,
              section: _section,
              category: _category,
              buOptions: _buOptions,
              sectionOptions: _sectionOptions,
              categoryOptions: _categoryOptions,
              sectionsEnabled: _bu != null && _bu!.isNotEmpty,
              hasFilters: _hasFilters,
              filterSummary: filterSummary,
              onBuSelected: _onBuChanged,
              onSectionSelected: _onSectionChanged,
              onCategorySelected: _onCategoryChanged,
              onClear: _clearFilters,
            ),
            const SizedBox(height: 20),
            _SectionTitle(
              title: filterSummary == null
                  ? 'Overview'
                  : 'Overview · $filterSummary',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Total',
                    value: stats.total,
                    icon: Icons.inventory_2_outlined,
                    color: GembaColors.brandPrimary,
                    onTap: () => widget.onNavigateToObservations(
                      GembaObservationFilter.all,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'In-progress',
                    value: stats.inProgress,
                    icon: Icons.pending_actions_outlined,
                    color: const Color(0xFFD97706),
                    onTap: () => widget.onNavigateToObservations(
                      GembaObservationFilter.inProgress,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Done',
                    value: stats.done,
                    icon: Icons.task_alt_outlined,
                    color: const Color(0xFF059669),
                    onTap: () => widget.onNavigateToObservations(
                      GembaObservationFilter.done,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Assigned to me',
                    value: stats.assignedTotal,
                    icon: Icons.assignment_ind_outlined,
                    color: const Color(0xFF0891B2),
                    subtitle: stats.assignedInProgress > 0
                        ? '${stats.assignedInProgress} need action'
                        : null,
                    onTap: () => widget.onNavigateToObservations(
                      GembaObservationFilter.assigned,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionTitle(title: 'Quick actions'),
            const SizedBox(height: 12),
            _QuickActionTile(
              icon: Icons.playlist_add_check_rounded,
              title: 'My assigned — action needed',
              subtitle: stats.assignedInProgress == 0
                  ? 'No in-progress items assigned to you'
                  : '${stats.assignedInProgress} observation${stats.assignedInProgress == 1 ? '' : 's'} waiting',
              accent: const Color(0xFFD97706),
              onTap: () => widget.onNavigateToObservations(
                GembaObservationFilter.assignedInProgress,
              ),
            ),
            const SizedBox(height: 10),
            _QuickActionTile(
              icon: Icons.assignment_ind_outlined,
              title: 'All assigned to me',
              subtitle: '${stats.assignedTotal} total · ${stats.assignedDone} done',
              accent: const Color(0xFF0891B2),
              onTap: () => widget.onNavigateToObservations(
                GembaObservationFilter.assigned,
              ),
            ),
            const SizedBox(height: 10),
            _QuickActionTile(
              icon: Icons.add_circle_outline_rounded,
              title: 'New observation',
              subtitle: 'Report a shop-floor finding',
              accent: GembaColors.brandPrimary,
              onTap: widget.onNavigateToAdd,
            ),
            if (stats.createdByMe > 0) ...[
              const SizedBox(height: 24),
              _SectionTitle(title: 'Your activity'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: GembaColors.brandTint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.edit_outlined, color: GembaColors.brandPrimary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${stats.createdByMe} created by you',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Observations you submitted on this device',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _firstName(String? name) {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return 'there';
    return trimmed.split(RegExp(r'\s+')).first;
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({
    required this.firstName,
    required this.employeeNumber,
  });

  final String firstName;
  final String? employeeNumber;

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
            color: GembaColors.brandPrimary.withValues(alpha: 0.25),
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
            child: const Icon(Icons.dashboard_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $firstName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  employeeNumber == null || employeeNumber!.isEmpty
                      ? 'Digital Gemba dashboard'
                      : 'Employee $employeeNumber',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: GembaColors.ink,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 14),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.85),
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

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: accent.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}
