import 'dart:ui';

import 'package:flutter/material.dart';

/// App theme colors used across loading states.
abstract final class LoadingTheme {
  static const primary = Color(0xFF0891B2);
  static const primaryLight = Color(0xFF0EA5E9);
  static const surface = Color(0xFFF9FAFB);
  static const text = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);

  static const gradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primary, primaryLight],
  );
}

enum LoadingPanelVariant { standard, submit }

/// Centered spinner card used in full-screen and inline loading states.
class LoadingPanel extends StatelessWidget {
  const LoadingPanel({
    super.key,
    this.message,
    this.color = LoadingTheme.primary,
    this.variant = LoadingPanelVariant.standard,
  });

  final String? message;
  final Color color;
  final LoadingPanelVariant variant;

  @override
  Widget build(BuildContext context) {
    if (variant == LoadingPanelVariant.submit) {
      return _SubmitLoadingPanel(message: message);
    }
    return _StandardLoadingPanel(message: message, color: color);
  }
}

class _StandardLoadingPanel extends StatelessWidget {
  const _StandardLoadingPanel({
    required this.message,
    required this.color,
  });

  final String? message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _LoadingCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SpinnerBadge(
              icon: Icons.hourglass_top_rounded,
              progressColor: color,
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                message!,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: LoadingTheme.text,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubmitLoadingPanel extends StatelessWidget {
  const _SubmitLoadingPanel({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final title = message?.trim().isNotEmpty == true
        ? message!.trim()
        : 'Submitting assessment...';
    final activeStep = _stepFromMessage(message);
    final subtitle = _subtitleForMessage(message);

    return _LoadingCard(
      maxWidth: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LoadingTheme.gradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _SpinnerBadge(
                  icon: Icons.cloud_upload_rounded,
                  progressColor: LoadingTheme.primary,
                  size: 72,
                  iconSize: 30,
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: LoadingTheme.text,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: LoadingTheme.textMuted,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                _SubmitStepRow(activeStep: activeStep),
                const SizedBox(height: 18),
                const _GradientProgressBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({
    required this.child,
    this.maxWidth = 280,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: LoadingTheme.border),
            boxShadow: [
              BoxShadow(
                color: LoadingTheme.primary.withValues(alpha: 0.12),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SpinnerBadge extends StatefulWidget {
  const _SpinnerBadge({
    required this.icon,
    required this.progressColor,
    this.size = 56,
    this.iconSize = 26,
  });

  final IconData icon;
  final Color progressColor;
  final double size;
  final double iconSize;

  @override
  State<_SpinnerBadge> createState() => _SpinnerBadgeState();
}

class _SpinnerBadgeState extends State<_SpinnerBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: _controller,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: widget.progressColor,
                backgroundColor: widget.progressColor.withValues(alpha: 0.12),
              ),
            ),
          ),
          Container(
            width: widget.size - 16,
            height: widget.size - 16,
            decoration: BoxDecoration(
              gradient: LoadingTheme.gradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: LoadingTheme.primary.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              widget.icon,
              color: Colors.white,
              size: widget.iconSize,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitStepRow extends StatelessWidget {
  const _SubmitStepRow({required this.activeStep});

  final int activeStep;

  static const _steps = <({String label, IconData icon})>[
    (label: 'Save', icon: Icons.save_outlined),
    (label: 'Photos', icon: Icons.photo_library_outlined),
    (label: 'Sync', icon: Icons.cloud_upload_outlined),
    (label: 'Email', icon: Icons.mark_email_read_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_steps.length, (index) {
        final step = _steps[index];
        final isDone = index < activeStep;
        final isActive = index == activeStep;

        return Expanded(
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: isActive || isDone ? LoadingTheme.gradient : null,
                  color: isActive || isDone
                      ? null
                      : LoadingTheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive || isDone
                        ? Colors.transparent
                        : LoadingTheme.border,
                  ),
                ),
                child: Icon(
                  isDone ? Icons.check_rounded : step.icon,
                  size: 16,
                  color: isActive || isDone
                      ? Colors.white
                      : LoadingTheme.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                step.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? LoadingTheme.primary
                      : LoadingTheme.textMuted,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _GradientProgressBar extends StatefulWidget {
  const _GradientProgressBar();

  @override
  State<_GradientProgressBar> createState() => _GradientProgressBarState();
}

class _GradientProgressBarState extends State<_GradientProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 4,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final segment = width * 0.35;
                final offset = (_controller.value * (width + segment)) - segment;
                return Stack(
                  children: [
                    Container(color: LoadingTheme.border),
                    Positioned(
                      left: offset,
                      width: segment,
                      top: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          gradient: LoadingTheme.gradient,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

int _stepFromMessage(String? message) {
  if (message == null || message.isEmpty) return 0;
  final m = message.toLowerCase();
  if (m.contains('email')) return 3;
  if (m.contains('submitting') || m.contains('uploading to server')) return 2;
  if (m.contains('photo')) return 1;
  return 0;
}

String _subtitleForMessage(String? message) {
  if (message == null || message.isEmpty) {
    return 'Please keep the app open while we finish.';
  }
  final m = message.toLowerCase();
  if (m.contains('photo')) {
    return 'Transferring images securely to the server.';
  }
  if (m.contains('submitting') || m.contains('uploading to server')) {
    return 'Recording your assessment in the database.';
  }
  if (m.contains('email')) {
    return 'Sending notification to the relevant team.';
  }
  if (m.contains('updating')) {
    return 'Applying your latest answers and photos.';
  }
  if (m.contains('saving')) {
    return 'Storing your responses on this device.';
  }
  return 'This may take a moment — please wait.';
}

/// Blocks interaction and shows a loading panel over [child].
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.variant = LoadingPanelVariant.standard,
  });

  final bool isLoading;
  final Widget child;
  final String? message;
  final LoadingPanelVariant variant;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: AbsorbPointer(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                builder: (context, opacity, _) {
                  return Opacity(
                    opacity: opacity,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                      child: ColoredBox(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.42),
                        child: Center(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.92, end: 1),
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutBack,
                            builder: (context, scale, child) {
                              return Transform.scale(
                                scale: scale,
                                child: child,
                              );
                            },
                            child: LoadingPanel(
                              message: message,
                              variant: variant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
