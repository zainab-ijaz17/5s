import 'package:flutter/material.dart';

import '../theme/gemba_colors.dart';
import 'gemba_searchable_picker.dart';

/// Collapsible BU / section / category filter panel for admin Gemba views.
class GembaLocationFilterPanel extends StatefulWidget {
  const GembaLocationFilterPanel({
    super.key,
    required this.bu,
    required this.section,
    required this.buOptions,
    required this.sectionOptions,
    required this.sectionsEnabled,
    required this.hasFilters,
    required this.filterSummary,
    required this.onBuSelected,
    required this.onSectionSelected,
    required this.onClear,
    this.category,
    this.categoryOptions = const [],
    this.onCategorySelected,
  });

  final String? bu;
  final String? section;
  final String? category;
  final List<GembaPickerOption> buOptions;
  final List<GembaPickerOption> sectionOptions;
  final List<GembaPickerOption> categoryOptions;
  final bool sectionsEnabled;
  final bool hasFilters;
  final String? filterSummary;
  final ValueChanged<String> onBuSelected;
  final ValueChanged<String> onSectionSelected;
  final ValueChanged<String>? onCategorySelected;
  final VoidCallback onClear;

  @override
  State<GembaLocationFilterPanel> createState() =>
      _GembaLocationFilterPanelState();
}

class _GembaLocationFilterPanelState extends State<GembaLocationFilterPanel> {
  bool _expanded = false;

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = (widget.bu?.isNotEmpty == true ? 1 : 0) +
        (widget.section?.isNotEmpty == true ? 1 : 0) +
        (widget.category?.isNotEmpty == true ? 1 : 0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.hasFilters ? GembaColors.brandPrimary : GembaColors.border,
        ),
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
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggleExpanded,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: widget.hasFilters
                            ? GembaColors.brandPrimary
                            : GembaColors.brandTint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: widget.hasFilters
                            ? Colors.white
                            : GembaColors.brandPrimary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Filters',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.filterSummary ??
                                'Tap to filter by BU, section, and category',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: widget.hasFilters
                                  ? GembaColors.brandPrimary
                                  : GembaColors.slate,
                              fontWeight: widget.hasFilters
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (activeCount > 0)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: GembaColors.brandTint,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$activeCount',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: GembaColors.brandPrimary,
                          ),
                        ),
                      ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: GembaColors.brandPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstCurve: Curves.easeOutCubic,
            secondCurve: Curves.easeOutCubic,
            sizeCurve: Curves.easeOutCubic,
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Divider(height: 1, color: GembaColors.border.withValues(alpha: 0.9)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GembaSearchablePickerField(
                        label: 'Business unit',
                        hint: 'All business units',
                        value: widget.bu,
                        options: widget.buOptions,
                        icon: Icons.business_outlined,
                        searchHint: 'Search BUs…',
                        onSelected: widget.onBuSelected,
                      ),
                      const SizedBox(height: 14),
                      GembaSearchablePickerField(
                        label: 'Section',
                        hint: widget.sectionsEnabled
                            ? 'All sections'
                            : 'Select a BU first',
                        value: widget.section,
                        options: widget.sectionOptions,
                        enabled: widget.sectionsEnabled,
                        icon: Icons.grid_view_rounded,
                        searchHint: 'Search sections…',
                        onSelected: widget.onSectionSelected,
                      ),
                      if (widget.categoryOptions.isNotEmpty &&
                          widget.onCategorySelected != null) ...[
                        const SizedBox(height: 14),
                        GembaSearchablePickerField(
                          label: 'Category',
                          hint: 'All categories',
                          value: widget.category,
                          options: widget.categoryOptions,
                          icon: Icons.category_outlined,
                          searchHint: 'Search categories…',
                          onSelected: widget.onCategorySelected!,
                        ),
                      ],
                      if (widget.hasFilters) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: widget.onClear,
                            icon: const Icon(Icons.clear_all_rounded, size: 18),
                            label: const Text('Clear filters'),
                            style: TextButton.styleFrom(
                              foregroundColor: GembaColors.brandPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
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
