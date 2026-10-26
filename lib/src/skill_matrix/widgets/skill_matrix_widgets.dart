import 'package:flutter/material.dart';

import '../theme/skill_matrix_theme.dart';

class SkillMatrixPageBackground extends StatelessWidget {
  const SkillMatrixPageBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: SkillMatrixTheme.scaffoldGradient,
        ),
      ),
      child: child,
    );
  }
}

class SkillMatrixHeroHeader extends StatelessWidget {
  const SkillMatrixHeroHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.badge,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: SkillMatrixTheme.headerGradient),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: SkillMatrixTheme.brandPrimary.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Skill Matrix',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(height: 12),
                  SkillMatrixPill(
                    label: badge!,
                    tone: SkillMatrixPillTone.neutralLight,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

enum SkillMatrixPillTone { neutral, neutralLight, ok, gap, draft, warning }

class SkillMatrixPill extends StatelessWidget {
  const SkillMatrixPill({
    super.key,
    required this.label,
    this.tone = SkillMatrixPillTone.neutral,
  });

  final String label;
  final SkillMatrixPillTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (tone) {
      SkillMatrixPillTone.neutral => (
          const Color(0xFFF1F5F9),
          SkillMatrixTheme.slate,
          SkillMatrixTheme.border,
        ),
      SkillMatrixPillTone.neutralLight => (
          Colors.white.withOpacity(0.2),
          Colors.white,
          Colors.white24,
        ),
      SkillMatrixPillTone.ok => (
          const Color(0xFFECFDF5),
          SkillMatrixTheme.success,
          const Color(0xFFA7F3D0),
        ),
      SkillMatrixPillTone.gap => (
          const Color(0xFFFEF2F2),
          SkillMatrixTheme.gap,
          const Color(0xFFFECACA),
        ),
      SkillMatrixPillTone.draft => (
          const Color(0xFFEFF6FF),
          const Color(0xFF2563EB),
          const Color(0xFFBFDBFE),
        ),
      SkillMatrixPillTone.warning => (
          SkillMatrixTheme.warningBg,
          const Color(0xFF9A3412),
          SkillMatrixTheme.warningBorder,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: fg,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }
}

class SkillMatrixStatTile {
  const SkillMatrixStatTile({
    required this.label,
    required this.value,
    this.highlight = false,
    this.icon,
    this.accentColor,
  });

  final String label;
  final String value;
  final bool highlight;
  final IconData? icon;
  final Color? accentColor;
}

/// Responsive stat tiles (2 columns on phone, 3 on wider layouts).
class SkillMatrixStatsGrid extends StatelessWidget {
  const SkillMatrixStatsGrid({super.key, required this.tiles});

  final List<SkillMatrixStatTile> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final columns = constraints.maxWidth >= 520 ? 3 : 2;
        final width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles)
              SizedBox(
                width: width,
                child: SkillMatrixStatCard(
                  label: tile.label,
                  value: tile.value,
                  highlight: tile.highlight,
                  icon: tile.icon,
                  accentColor: tile.accentColor,
                ),
              ),
          ],
        );
      },
    );
  }
}

class SkillMatrixStatCard extends StatelessWidget {
  const SkillMatrixStatCard({
    super.key,
    required this.label,
    required this.value,
    this.highlight = false,
    this.icon,
    this.accentColor,
  });

  final String label;
  final String value;
  final bool highlight;
  final IconData? icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ??
        (highlight ? SkillMatrixTheme.brandPrimary : SkillMatrixTheme.brandDark);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            accent.withOpacity(highlight ? 0.12 : 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? accent.withOpacity(0.45)
              : SkillMatrixTheme.border,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
          if (icon != null) const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: accent,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: SkillMatrixTheme.slate,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable hub row (e.g. open skill matrix, view all assessments).
class SkillMatrixHubActionCard extends StatelessWidget {
  const SkillMatrixHubActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.accent = SkillMatrixTheme.brandPrimary,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SkillMatrixTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accent, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: SkillMatrixTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: SkillMatrixTheme.slate,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SkillMatrixSectionCard extends StatelessWidget {
  const SkillMatrixSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SkillMatrixTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: SkillMatrixTheme.ink,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: SkillMatrixTheme.slate,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class SkillMatrixFieldLabel extends StatelessWidget {
  const SkillMatrixFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: SkillMatrixTheme.slate,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class SkillMatrixReadonlyField extends StatelessWidget {
  const SkillMatrixReadonlyField({super.key, required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SkillMatrixTheme.border),
      ),
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: SkillMatrixTheme.ink,
        ),
      ),
    );
  }
}

/// Shared input styling for Skill Matrix forms.
InputDecoration skillMatrixInputDecoration({
  String? label,
  String? hint,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    suffixIcon: suffixIcon,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: SkillMatrixTheme.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: SkillMatrixTheme.brandPrimary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}

class SkillMatrixPrimaryButton extends StatelessWidget {
  const SkillMatrixPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: SkillMatrixTheme.brandPrimary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: loading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ],
            ),
    );
  }
}

class SkillMatrixEmptyState extends StatelessWidget {
  const SkillMatrixEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SkillMatrixTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: SkillMatrixTheme.slate),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: SkillMatrixTheme.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: SkillMatrixTheme.slate,
              height: 1.45,
              fontSize: 13.5,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            SkillMatrixPrimaryButton(
              label: actionLabel!,
              onPressed: onAction,
              icon: Icons.add_rounded,
            ),
          ],
        ],
      ),
    );
  }
}

class SkillMatrixSearchBar extends StatelessWidget {
  const SkillMatrixSearchBar({
    super.key,
    required this.hint,
    required this.onChanged,
  });

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: skillMatrixInputDecoration(hint: hint).copyWith(
        prefixIcon: const Icon(Icons.search_rounded, color: SkillMatrixTheme.slate),
      ),
    );
  }
}
