import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/gemba_observation.dart';
import '../../services/gemba_observation_photos.dart';
import '../../services/gemba_observations_service.dart';
import '../../services/gemba_session_service.dart';
import '../../theme/gemba_colors.dart';
import '../../widgets/gemba_feedback.dart';

class GembaMarkObservationDoneScreen extends StatefulWidget {
  const GembaMarkObservationDoneScreen({
    super.key,
    required this.observationId,
  });

  final String observationId;

  @override
  State<GembaMarkObservationDoneScreen> createState() =>
      _GembaMarkObservationDoneScreenState();
}

class _GembaMarkObservationDoneScreenState
    extends State<GembaMarkObservationDoneScreen> {
  final _remarksController = TextEditingController();
  final _pageController = PageController();
  final _picker = ImagePicker();

  int _step = 0;
  bool _saving = false;
  final List<XFile> _photos = [];
  GembaObservation? _observation;

  static const _stepMeta = [
    (
      title: 'After remarks',
      subtitle: 'Describe what was done',
      icon: Icons.edit_note_rounded,
    ),
    (
      title: 'After photos',
      subtitle: 'Capture completion evidence',
      icon: Icons.photo_camera_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadObservation();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadObservation() async {
    try {
      final observation = await GembaObservationsService.instance.fetchById(
        widget.observationId,
      );
      if (!mounted) return;
      setState(() => _observation = observation);
    } catch (_) {
      await GembaObservationsService.instance.ensureLoaded();
      if (!mounted) return;
      setState(() {
        _observation =
            GembaObservationsService.instance.findById(widget.observationId);
      });
    }
    }

  Future<void> _pickFromCamera() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() => _photos.add(file));
  }

  Future<void> _pickFromGallery() async {
    final files = await _picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    setState(() => _photos.addAll(files));
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  bool _validateRemarks() {
    if (_remarksController.text.trim().isEmpty) {
      GembaFeedback.showError(context, 'Enter after observation remarks');
      return false;
    }
    return true;
  }

  Future<void> _goNext() async {
    if (_step == 0) {
      if (!_validateRemarks()) return;
      setState(() => _step = 1);
      await _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _submit();
  }

  Future<void> _goBack() async {
    if (_step <= 0) return;
    setState(() => _step -= 1);
    await _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _submit() async {
    if (!_validateRemarks()) return;

    final session = await GembaSessionService.instance.loadSession();
    if (session == null) {
      GembaFeedback.showError(context, 'Sign in again to complete this observation');
      return;
    }

    final observation = _observation;
    if (observation == null) {
      GembaFeedback.showError(context, 'Observation not found');
      return;
    }

    if (!observation.isAssignedTo(session.user.employeeNumber)) {
      GembaFeedback.showError(
        context,
        'Only the assigned employee can mark this as done',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final afterPhotoPaths = await GembaObservationPhotos.persistPhotos(
        observationId: observation.id,
        photos: _photos,
        filePrefix: 'after',
      );

      await GembaObservationsService.instance.markAsDone(
        id: observation.id,
        afterRemarks: _remarksController.text.trim(),
        afterPhotoPaths: afterPhotoPaths,
        completedByEmployeeNumber: session.user.employeeNumber,
        completedByName: session.user.name,
      );

      if (!mounted) return;
      GembaFeedback.showSuccess(
        context,
        'Observation marked as Done successfully',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      GembaFeedback.showError(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final observation = _observation;
    if (observation == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mark as Done'),
          backgroundColor: GembaColors.brandPrimary,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: GembaColors.brandPrimary),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark as Done'),
        backgroundColor: GembaColors.brandPrimary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: GembaColors.scaffoldGradient,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    observation.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: GembaColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Step ${_step + 1} of 2 · ${_stepMeta[_step].title}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: GembaColors.slate,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _StepProgress(current: _step, steps: _stepMeta),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildRemarksStep(),
                  _buildPhotosStep(),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (_step > 0) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : _goBack,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: GembaColors.brandPrimary,
                            side: const BorderSide(color: GembaColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Back',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: _step > 0 ? 2 : 1,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _goNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GembaColors.brandPrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _step == 1 ? 'Save & mark Done' : 'Continue',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemarksStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
              const Row(
                children: [
                  Icon(Icons.notes_rounded, color: GembaColors.brandPrimary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'After observation remarks',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: GembaColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Describe actions taken and the current state after your visit.',
                style: TextStyle(color: GembaColors.slate, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _remarksController,
                minLines: 7,
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText: 'After remarks',
                  hintText: 'What was done to address this observation?',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotosStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.collections_outlined, color: GembaColors.brandPrimary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'After photos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: GembaColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Optional — add photos showing the completed state.',
                style: TextStyle(color: GembaColors.slate, height: 1.4),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFromCamera,
                      icon: const Icon(Icons.photo_camera_rounded),
                      label: const Text('Camera'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: GembaColors.brandPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: GembaColors.brandPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_photos.isEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  decoration: BoxDecoration(
                    color: GembaColors.brandTint,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: GembaColors.border),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 40,
                        color: GembaColors.brandPrimary,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No after photos yet',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: GembaColors.ink,
                        ),
                      ),
                    ],
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _photos.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(_photos[index].path),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Material(
                            color: Colors.black54,
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: () => _removePhoto(index),
                              customBorder: const CircleBorder(),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.current, required this.steps});

  final int current;
  final List<({String title, String subtitle, IconData icon})> steps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: i <= current
                        ? GembaColors.brandPrimary
                        : const Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                    boxShadow: i == current
                        ? [
                            BoxShadow(
                              color: GembaColors.brandPrimary
                                  .withValues(alpha: 0.28),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    i < current ? Icons.check_rounded : steps[i].icon,
                    size: 20,
                    color: i <= current ? Colors.white : GembaColors.slate,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  steps[i].title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight:
                        i == current ? FontWeight.w800 : FontWeight.w600,
                    color: i <= current
                        ? GembaColors.ink
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          if (i < steps.length - 1)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 3,
                  decoration: BoxDecoration(
                    color: i < current
                        ? GembaColors.brandPrimary
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
