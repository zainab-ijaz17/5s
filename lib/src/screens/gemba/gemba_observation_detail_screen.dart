import 'package:flutter/material.dart';
import '../../theme/gemba_colors.dart';

import '../../models/gemba_observation_status.dart';
import '../../models/gemba_observation.dart';
import '../../services/gemba_observation_photos.dart';
import '../../services/gemba_observations_service.dart';
import '../../services/gemba_session_service.dart';
import 'gemba_mark_observation_done_screen.dart';

class GembaObservationDetailScreen extends StatefulWidget {
  const GembaObservationDetailScreen({
    super.key,
    required this.observationId,
  });

  final String observationId;

  @override
  State<GembaObservationDetailScreen> createState() =>
      _GembaObservationDetailScreenState();
}

class _GembaObservationDetailScreenState
    extends State<GembaObservationDetailScreen> {
  GembaObservation? _observation;
  String? _currentEmployeeNumber;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadObservation();
  }

  Future<void> _loadObservation() async {
    final session = await GembaSessionService.instance.loadSession();
    setState(() => _loading = true);
    try {
      GembaObservation? observation =
          await GembaObservationsService.instance.fetchById(
        widget.observationId,
      );
      observation ??=
          GembaObservationsService.instance.findById(widget.observationId);
      if (!mounted) return;
      setState(() {
        _currentEmployeeNumber = session?.user.employeeNumber;
        _observation = observation;
        _loading = false;
      });
    } catch (_) {
      await GembaObservationsService.instance.ensureLoaded();
      if (!mounted) return;
      setState(() {
        _currentEmployeeNumber = session?.user.employeeNumber;
        _observation =
            GembaObservationsService.instance.findById(widget.observationId);
        _loading = false;
      });
    }
  }

  Future<void> _openMarkAsDone(GembaObservation observation) async {
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => GembaMarkObservationDoneScreen(
          observationId: observation.id,
        ),
      ),
    );
    if (completed == true) {
      await _loadObservation();
    }
  }

  Color _statusColor(GembaObservation observation) {
    if (observation.isDone) return const Color(0xFF059669);
    return const Color(0xFFD97706);
  }

  String _assigneeLabel(GembaObservation observation) {
    final name = observation.assignedEmployeeName?.trim();
    if (name != null && name.isNotEmpty) {
      return '$name (${observation.assignedEmployeeNumber})';
    }
    return observation.assignedEmployeeNumber;
  }

  String _creatorLabel(GembaObservation observation) {
    final name = observation.createdByName?.trim();
    if (name != null && name.isNotEmpty) {
      return '$name (${observation.createdByEmployeeNumber})';
    }
    return observation.createdByEmployeeNumber;
  }

  String _formatDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[value.month - 1];
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$month ${value.day}, ${value.year} · $hour:$minute $period';
  }

  List<String> _existingPhotoPaths(GembaObservation observation) {
    final paths = List<String>.from(observation.photoPaths);
    return paths.where(GembaObservationPhotos.existsAt).toList(growable: false);
  }

  List<String> _existingAfterPhotoPaths(GembaObservation observation) {
    final paths = List<String>.from(observation.afterPhotoPaths);
    return paths.where(GembaObservationPhotos.existsAt).toList(growable: false);
  }

  bool _canMarkAsDone(GembaObservation observation) {
    if (observation.isDone) return false;
    final mine = (_currentEmployeeNumber ?? '').trim();
    if (mine.isEmpty) return false;
    return observation.isAssignedTo(mine);
  }

  void _openPhotoViewer(
    BuildContext context,
    List<String> paths,
    int initialIndex,
  ) {
    if (paths.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PhotoViewerScreen(
          paths: paths,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Widget _photoGallery(
    BuildContext context,
    List<String> photos,
    void Function(int index) onTap,
  ) {
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => onTap(index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1,
                child: GembaObservationPhotos.buildImage(
                  photos[index],
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F7FA),
        appBar: AppBar(
          title: const Text('Observation details'),
          backgroundColor: GembaColors.brandPrimary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final observation = _observation;
    if (observation == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F7FA),
        appBar: AppBar(
          title: const Text('Observation details'),
          backgroundColor: GembaColors.brandPrimary,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text(
            'Observation not found.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    final photos = _existingPhotoPaths(observation);
    final afterPhotos = _existingAfterPhotoPaths(observation);
    final statusColor = _statusColor(observation);
    final canMarkAsDone = _canMarkAsDone(observation);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FA),
      appBar: AppBar(
        title: const Text('Observation details'),
        backgroundColor: GembaColors.brandPrimary,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: canMarkAsDone
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: ElevatedButton.icon(
                  onPressed: () => _openMarkAsDone(observation),
                  icon: const Icon(Icons.task_alt_rounded),
                  label: const Text('Mark as Done'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GembaColors.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            )
          : null,
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, canMarkAsDone ? 8 : 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        GembaObservationStatus.normalize(observation.status),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatDate(observation.createdAt),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  observation.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 16),
                _InfoTile(
                  icon: Icons.place_outlined,
                  label: 'Location',
                  value: observation.location,
                ),
                _InfoTile(
                  icon: Icons.category_outlined,
                  label: 'Category',
                  value: observation.category,
                ),
                if (observation.bu != null && observation.bu!.isNotEmpty)
                  _InfoTile(
                    icon: Icons.business_outlined,
                    label: 'Business unit',
                    value: observation.bu!,
                  ),
                if (observation.section != null &&
                    observation.section!.isNotEmpty)
                  _InfoTile(
                    icon: Icons.grid_view_rounded,
                    label: 'Section',
                    value: observation.section!,
                  ),
                if (observation.machineValue != null &&
                    observation.machineValue!.isNotEmpty)
                  _InfoTile(
                    icon: Icons.precision_manufacturing_outlined,
                    label: 'Machine',
                    value: observation.machineValue!,
                  ),
                _InfoTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Assigned to',
                  value: _assigneeLabel(observation),
                ),
                _InfoTile(
                  icon: Icons.edit_outlined,
                  label: 'Created by',
                  value: _creatorLabel(observation),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (photos.isNotEmpty) ...[
            Row(
              children: [
                const Text(
                  'Before photos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: GembaColors.ink,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${photos.length})',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _photoGallery(
              context,
              photos,
              (index) => _openPhotoViewer(context, photos, index),
            ),
            const SizedBox(height: 18),
          ] else if (observation.photoCount > 0) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.photo_outlined, color: Color(0xFFD97706)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Photos were attached but are no longer available on this device.',
                      style: TextStyle(color: Color(0xFF92400E), height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Before remarks',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: GembaColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  observation.remarks.isEmpty
                      ? 'No remarks provided.'
                      : observation.remarks,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    height: 1.45,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          if (observation.isDone) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'After remarks',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: GembaColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    (observation.afterRemarks ?? '').trim().isEmpty
                        ? 'No after remarks provided.'
                        : observation.afterRemarks!.trim(),
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      height: 1.45,
                      fontSize: 15,
                    ),
                  ),
                  if (observation.completedAt != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Completed ${_formatDate(observation.completedAt!)}',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (afterPhotos.isNotEmpty) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  const Text(
                    'After photos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: GembaColors.ink,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${afterPhotos.length})',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _photoGallery(
                context,
                afterPhotos,
                (index) => _openPhotoViewer(context, afterPhotos, index),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: GembaColors.brandPrimary),
          const SizedBox(width: 10),
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoViewerScreen extends StatefulWidget {
  const _PhotoViewerScreen({
    required this.paths,
    required this.initialIndex,
  });

  final List<String> paths;
  final int initialIndex;

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Photo ${_index + 1} of ${widget.paths.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.paths.length,
        onPageChanged: (value) => setState(() => _index = value),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Center(
              child: GembaObservationPhotos.buildImage(
                widget.paths[index],
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}
