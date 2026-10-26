import 'package:flutter/material.dart';
import '../../theme/gemba_colors.dart';

import '../../data/gemba_org_data.dart';
import '../../models/gemba_observation.dart';
import '../../models/gemba_observation_status.dart';
import '../../services/api_service.dart';
import '../../services/gemba_pdf_export_service.dart';
import '../../services/gemba_report_pdf_service.dart';
import '../../services/gemba_session_service.dart';
import '../../widgets/gemba_searchable_picker.dart';

class GembaReportScreen extends StatefulWidget {
  const GembaReportScreen({super.key});

  @override
  State<GembaReportScreen> createState() => _GembaReportScreenState();
}

class _GembaReportScreenState extends State<GembaReportScreen> {
  bool _loading = true;
  bool _generating = false;
  String? _error;
  bool _isAdmin = false;
  List<GembaObservation> _observations = const [];

  String? _company;
  String? _bu;
  String? _section;
  String? _category;
  GembaReportStatusFilter _statusFilter = GembaReportStatusFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _isPcl => _company == 'Packages Convertors Limited';

  List<String> get _sections {
    if (!_isPcl || _bu == null) return const [];
    return GembaOrgData.pclBuSections[_bu!] ?? const [];
  }

  List<GembaPickerOption> get _companyOptions => [
        for (final c in GembaOrgData.companies)
          GembaPickerOption(value: c, title: c),
      ];

  List<GembaPickerOption> get _buOptions => [
        for (final bu in GembaOrgData.pclBuSfDivisionIds.keys)
          GembaPickerOption(value: bu, title: bu),
      ];

  List<GembaPickerOption> get _sectionOptions => [
        for (final s in _sections) GembaPickerOption(value: s, title: s),
      ];

  List<GembaPickerOption> get _categoryOptions => [
        for (final c in GembaOrgData.observationCategories)
          GembaPickerOption(value: c, title: c),
      ];

  bool get _hasLocationFilters =>
      (_company?.isNotEmpty ?? false) ||
      (_bu?.isNotEmpty ?? false) ||
      (_section?.isNotEmpty ?? false) ||
      (_category?.isNotEmpty ?? false);

  bool get _hasFilters =>
      _hasLocationFilters || _statusFilter != GembaReportStatusFilter.all;

  String get _filterSummary {
    final parts = <String>[];
    if (_statusFilter != GembaReportStatusFilter.all) {
      parts.add(_statusFilter.label);
    }
    if (_company != null && _company!.isNotEmpty) parts.add(_company!);
    if (_bu != null && _bu!.isNotEmpty) parts.add(_bu!);
    if (_section != null && _section!.isNotEmpty) parts.add(_section!);
    if (_category != null && _category!.isNotEmpty) parts.add(_category!);
    return parts.isEmpty ? 'All observations' : parts.join(' / ');
  }

  bool _matchesStatus(GembaObservation observation) {
    return switch (_statusFilter) {
      GembaReportStatusFilter.all => true,
      GembaReportStatusFilter.open => !observation.isDone,
      GembaReportStatusFilter.closed => observation.isDone,
    };
  }

  List<GembaObservation> get _filteredObservations {
    return _observations.where((o) {
      if (!_matchesStatus(o)) return false;
      if (_company != null &&
          _company!.isNotEmpty &&
          o.company != _company) {
        return false;
      }
      if (_bu != null && _bu!.isNotEmpty && (o.bu ?? '').trim() != _bu) {
        return false;
      }
      if (_section != null &&
          _section!.isNotEmpty &&
          (o.section ?? '').trim() != _section) {
        return false;
      }
      if (_category != null &&
          _category!.isNotEmpty &&
          o.category.trim() != _category) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  String _reportFileName() {
    final parts = <String>[];
    if (_statusFilter != GembaReportStatusFilter.all) {
      parts.add(_statusFilter.name);
    }
    if (_bu != null && _bu!.isNotEmpty) {
      parts.add(_bu!.toLowerCase());
    }
    if (_section != null && _section!.isNotEmpty) {
      parts.add(_section!.toLowerCase().replaceAll(' ', '-'));
    }
    if (_category != null && _category!.isNotEmpty) {
      parts.add(_category!.toLowerCase().replaceAll(' ', '-'));
    }
    if (parts.isEmpty) return 'gemba-report-all';
    return 'gemba-report-${parts.join('-')}';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await GembaSessionService.instance.loadSession();
      final token = session?.accessToken;
      if (token == null || token.isEmpty) {
        throw Exception('Sign in again');
      }

      final isAdmin = session!.user.isAdmin;
      final observations = <GembaObservation>[];

      if (isAdmin) {
        final response = await ApiService.get(
          '/gemba/admin/summary',
          accessToken: token,
        );
        if (response is! Map) {
          throw Exception('Invalid reports summary response');
        }
        final map = Map<String, dynamic>.from(response);
        final list = map['observations'];
        if (list is List) {
          for (final row in list) {
            if (row is! Map) continue;
            observations.add(
              GembaObservation.fromJson(Map<String, dynamic>.from(row)),
            );
          }
        }
      } else {
        final response = await ApiService.get(
          '/gemba/observations',
          accessToken: token,
        );
        if (response is List) {
          for (final row in response) {
            if (row is! Map) continue;
            observations.add(
              GembaObservation.fromJson(Map<String, dynamic>.from(row)),
            );
          }
        } else if (response is Map) {
          final map = Map<String, dynamic>.from(response);
          for (final key in ['data', 'observations', 'results', 'items']) {
            final nested = map[key];
            if (nested is! List) continue;
            for (final row in nested) {
              if (row is! Map) continue;
              observations.add(
                GembaObservation.fromJson(Map<String, dynamic>.from(row)),
              );
            }
            break;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _isAdmin = isAdmin;
        _observations = observations;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onCompanyChanged(String value) {
    setState(() {
      _company = value;
      _bu = null;
      _section = null;
    });
  }

  void _onBuChanged(String value) {
    setState(() {
      _bu = value;
      _section = null;
    });
  }

  Future<void> _generatePdf() async {
    if (_generating) return;

    final matching = _filteredObservations;
    if (matching.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_statusFilter.emptyMessage),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _generating = true);
    try {
      final session = await GembaSessionService.instance.loadSession();
      final token = session?.accessToken;
      if (token == null || token.isEmpty) {
        throw Exception('Sign in again');
      }

      final bytes = await GembaReportPdfService.build(
        observations: matching,
        company: _company,
        bu: _bu,
        section: _section,
        category: _category,
        statusFilter: _statusFilter,
        accessToken: token,
      );

      if (!mounted) return;

      final fileName = _reportFileName();

      final box = context.findRenderObject() as RenderBox?;
      await GembaPdfExportService.share(
        bytes: bytes,
        filename: '$fileName.pdf',
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', 'Could not generate PDF: '),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matching = _filteredObservations;

    return Scaffold(
      backgroundColor: GembaColors.brandTint,
      appBar: AppBar(
        title: const Text('Generate report'),
        backgroundColor: GembaColors.brandPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: GembaColors.headerGradientSimple,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.picture_as_pdf_outlined,
                            color: Colors.white, size: 32),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Generate report',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Filter by status and location, then export a PDF with photos and remarks.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFB91C1C)),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _PanelHeader(
                          icon: Icons.filter_list_rounded,
                          title: 'Filters',
                          subtitle:
                              'Optional — choose status and location, or leave blank for everything',
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: GembaColors.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<GembaReportStatusFilter>(
                          segments: const [
                            ButtonSegment(
                              value: GembaReportStatusFilter.all,
                              label: Text('All'),
                              icon: Icon(Icons.list_alt_rounded, size: 18),
                            ),
                            ButtonSegment(
                              value: GembaReportStatusFilter.open,
                              label: Text('Open'),
                              icon: Icon(Icons.pending_actions_outlined, size: 18),
                            ),
                            ButtonSegment(
                              value: GembaReportStatusFilter.closed,
                              label: Text('Closed'),
                              icon: Icon(Icons.check_circle_outline, size: 18),
                            ),
                          ],
                          selected: {_statusFilter},
                          onSelectionChanged: (selection) {
                            setState(() {
                              _statusFilter = selection.first;
                            });
                          },
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(height: 18),
                        GembaSearchablePickerField(
                          label: 'Company',
                          hint: 'All companies (optional)',
                          value: _company,
                          options: _companyOptions,
                          searchHint: 'Search companies…',
                          icon: Icons.apartment_rounded,
                          onSelected: _onCompanyChanged,
                        ),
                        if (_hasFilters) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => setState(() {
                                _company = null;
                                _bu = null;
                                _section = null;
                                _category = null;
                                _statusFilter = GembaReportStatusFilter.all;
                              }),
                              icon: const Icon(Icons.filter_alt_off_outlined,
                                  size: 18),
                              label: const Text('Clear filters'),
                            ),
                          ),
                        ],
                        if (_isPcl) ...[
                          const SizedBox(height: 16),
                          GembaSearchablePickerField(
                            label: 'Business Unit',
                            hint: 'Select business unit',
                            value: _bu,
                            options: _buOptions,
                            searchHint: 'Search BU…',
                            icon: Icons.business_rounded,
                            onSelected: _onBuChanged,
                          ),
                          if (_bu != null) ...[
                            const SizedBox(height: 16),
                            GembaSearchablePickerField(
                              label: 'Section',
                              hint: 'Choose a section',
                              value: _section,
                              options: _sectionOptions,
                              searchHint: 'Search sections…',
                              icon: Icons.grid_view_rounded,
                              onSelected: (v) => setState(() => _section = v),
                            ),
                          ],
                        ],
                        const SizedBox(height: 16),
                        GembaSearchablePickerField(
                          label: 'Category',
                          hint: 'All categories (optional)',
                          value: _category,
                          options: _categoryOptions,
                          searchHint: 'Search categories…',
                          icon: Icons.category_outlined,
                          onSelected: (v) => setState(() => _category = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: GembaColors.brandTint,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.check_circle_outline_rounded,
                            color: GembaColors.brandPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${matching.length} observation${matching.length == 1 ? '' : 's'} ready',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: GembaColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _hasFilters
                                    ? 'Filters: $_filterSummary'
                                    : 'No filters applied — all observations will be included.',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: !_generating ? _generatePdf : null,
                    icon: _generating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download_rounded),
                    label: Text(
                      _generating ? 'Generating PDF…' : 'Generate PDF',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: GembaColors.brandPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: GembaColors.brandTint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: GembaColors.brandPrimary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: GembaColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
