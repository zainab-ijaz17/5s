import 'package:flutter/material.dart';
import '../../theme/gemba_colors.dart';

import '../../models/gemba_observation.dart';
import '../../models/gemba_user.dart';
import '../../services/api_service.dart';
import '../../services/gemba_observations_service.dart';
import '../../services/gemba_session_service.dart';
import 'gemba_admin_report_screen.dart';
import 'gemba_observation_detail_screen.dart';

/// Reports tab — PDF export for all users; org-wide stats for admins only.
class GembaReportsScreen extends StatefulWidget {
  const GembaReportsScreen({super.key});

  @override
  State<GembaReportsScreen> createState() => _GembaReportsScreenState();
}

class _GembaReportsScreenState extends State<GembaReportsScreen> {
  bool _loading = true;
  String? _error;
  GembaUser? _user;
  int _total = 0;
  int _inProgress = 0;
  int _done = 0;
  List<GembaObservation> _observations = const [];

  bool get _isAdmin => _user?.isAdmin ?? false;

  @override
  void initState() {
    super.initState();
    _load();
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

      final user = session!.user;
      final isAdmin = user.isAdmin;

      if (isAdmin) {
        final response = await ApiService.get(
          '/gemba/admin/summary',
          accessToken: token,
        );
        if (response is! Map) {
          throw Exception('Invalid reports summary response');
        }
        final map = Map<String, dynamic>.from(response);
        final observations = _parseObservations(map['observations']);

        if (!mounted) return;
        setState(() {
          _user = user;
          _total = _readCount(map['total'], observations.length);
          _inProgress = _readCount(map['inProgress'], 0);
          _done = _readCount(map['done'], 0);
          _observations = observations;
        });
      } else {
        await GembaObservationsService.instance.reload();
        final items = GembaObservationsService.instance.items;
        var inProgress = 0;
        var done = 0;
        for (final item in items) {
          if (item.isDone) {
            done++;
          } else {
            inProgress++;
          }
        }

        if (!mounted) return;
        setState(() {
          _user = user;
          _total = items.length;
          _inProgress = inProgress;
          _done = done;
          _observations = items;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<GembaObservation> _parseObservations(dynamic list) {
    final observations = <GembaObservation>[];
    if (list is! List) return observations;
    for (final row in list) {
      if (row is! Map) continue;
      observations.add(
        GembaObservation.fromJson(Map<String, dynamic>.from(row)),
      );
    }
    return observations;
  }

  int _readCount(dynamic value, int fallback) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  List<GembaObservation> get _listedObservations => _observations;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: GembaColors.brandPrimary),
      );
    }

    final listed = _listedObservations;

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
        color: GembaColors.brandPrimary,
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
              child: Row(
                children: [
                  const Icon(
                    Icons.assessment_outlined,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isAdmin ? 'Reports' : 'Your reports',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isAdmin
                              ? 'Export observations as PDF with flexible filters'
                              : 'Export your observations as PDF',
                          style: const TextStyle(
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
              Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: _isAdmin ? 'Total' : 'Yours',
                    value: '$_total',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(label: 'In-progress', value: '$_inProgress'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(label: 'Done', value: '$_done'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const GembaReportScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Generate report'),
              style: FilledButton.styleFrom(
                backgroundColor: GembaColors.ink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _isAdmin ? 'All observations' : 'Your observations',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: GembaColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            if (listed.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    _isAdmin
                        ? 'No observations in the database yet'
                        : 'No observations to include in a report yet',
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
              )
            else
              for (final item in listed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReportObservationTile(
                    item: item,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => GembaObservationDetailScreen(
                            observationId: item.id,
                          ),
                        ),
                      );
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: GembaColors.brandPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportObservationTile extends StatelessWidget {
  const _ReportObservationTile({
    required this.item,
    required this.onTap,
  });

  final GembaObservation item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.category} · ${item.status}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Assigned: ${item.assignedEmployeeNumber}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: GembaColors.brandPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}
