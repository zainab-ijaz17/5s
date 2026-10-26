import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Shared Packages Group auth background with optional watermark logo.
class PackagesBrandedShell extends StatelessWidget {
  const PackagesBrandedShell({
    super.key,
    required this.child,
    this.showBackButton = false,
    this.onBack,
    this.watermarkOpacity = 0.08,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
  });

  static const logoAsset = 'assets/images/packages-logo.svg';

  final Widget child;
  final bool showBackButton;
  final VoidCallback? onBack;
  final double watermarkOpacity;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
              Color(0xFF134E4A),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Opacity(
                    opacity: watermarkOpacity,
                    child: SvgPicture.asset(
                      logoAsset,
                      width: 320,
                      height: 320,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showBackButton)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: Colors.white,
                        tooltip: 'Back',
                      ),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: padding,
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White auth card with inner logo watermark (incident-report style).
class PackagesAuthCard extends StatelessWidget {
  const PackagesAuthCard({
    super.key,
    required this.child,
    this.maxWidth = 440,
    this.borderRadius = 22,
    this.padding = const EdgeInsets.fromLTRB(28, 32, 28, 32),
  });

  final Widget child;
  final double maxWidth;
  final double borderRadius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(
        width: double.infinity,
        child: Card(
          elevation: 18,
          margin: EdgeInsets.zero,
          shadowColor: Colors.black.withOpacity(0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Color(0xFFF8FAFC)],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Opacity(
                        opacity: 0.05,
                        child: SvgPicture.asset(
                          PackagesBrandedShell.logoAsset,
                          width: 260,
                          height: 260,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: padding,
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PackagesBrandHeader extends StatelessWidget {
  const PackagesBrandHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.logoSize = 52,
  });

  final String title;
  final String subtitle;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SvgPicture.asset(
          PackagesBrandedShell.logoAsset,
          width: logoSize,
          height: logoSize,
          placeholderBuilder: (_) => Container(
            width: logoSize,
            height: logoSize,
            decoration: BoxDecoration(
              color: const Color(0xFF008FD5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.business_rounded, color: Colors.white),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Footer branding block used on app selection and auth screens (incident-report style).
class PackagesCopyrightFooter extends StatelessWidget {
  const PackagesCopyrightFooter({super.key});

  static const _muted = Color(0xFF64748B);
  static const _ink = Color(0xFF0F172A);
  static const _logoBlue = Color(0xFF008FD5);

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;

    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'POWERED BY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                    color: _muted,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 34,
                      child: SvgPicture.asset(
                        PackagesBrandedShell.logoAsset,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Packages',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _logoBlue,
                              letterSpacing: -0.2,
                              height: 1.2,
                            ),
                          ),
                          const TextSpan(
                            text: ' Group',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _ink,
                              letterSpacing: -0.2,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '© $year Packages Group. All rights reserved.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: _muted,
                    height: 1.35,
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
