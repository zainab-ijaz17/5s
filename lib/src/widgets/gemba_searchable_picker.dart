import 'package:flutter/material.dart';
import '../theme/gemba_colors.dart';

class GembaPickerOption {
  const GembaPickerOption({
    required this.value,
    required this.title,
    this.subtitle,
    this.leadingLabel,
  });

  final String value;
  final String title;
  final String? subtitle;

  /// Optional short badge (e.g. machine code).
  final String? leadingLabel;
}

/// Tappable field that opens a searchable bottom-sheet option list.
class GembaSearchablePickerField extends StatelessWidget {
  const GembaSearchablePickerField({
    super.key,
    required this.label,
    required this.hint,
    required this.options,
    required this.onSelected,
    this.value,
    this.enabled = true,
    this.icon = Icons.unfold_more_rounded,
    this.searchHint = 'Search…',
  });

  final String label;
  final String hint;
  final String? value;
  final List<GembaPickerOption> options;
  final ValueChanged<String> onSelected;
  final bool enabled;
  final IconData icon;
  final String searchHint;

  GembaPickerOption? get _selected {
    if (value == null) return null;
    for (final o in options) {
      if (o.value == value) return o;
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    if (!enabled) return;
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No employees loaded yet. Pull to retry or go back and continue again.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    final selected = await showGembaSearchablePicker(
      context: context,
      title: label,
      options: options,
      selectedValue: value,
      searchHint: searchHint,
    );
    if (selected != null) onSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final hasValue = selected != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: enabled ? () => _open(context) : null,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasValue
                      ? const Color(0xFF99F6E4)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  if (selected?.leadingLabel != null) ...[
                    _CodeBadge(selected!.leadingLabel!),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: hasValue
                        ? (selected.subtitle == null ||
                                selected.subtitle!.isEmpty
                            ? Text(
                                selected.title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                              )
                            : Row(
                                children: [
                                  Text(
                                    selected.title,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      selected.subtitle!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        color: Color(0xFF475569),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ))
                        : Text(
                            hint,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                  Icon(
                    icon,
                    color: enabled
                        ? GembaColors.brandPrimary
                        : const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<String?> showGembaSearchablePicker({
  required BuildContext context,
  required String title,
  required List<GembaPickerOption> options,
  String? selectedValue,
  String searchHint = 'Search…',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _GembaSearchablePickerSheet(
        title: title,
        options: options,
        selectedValue: selectedValue,
        searchHint: searchHint,
      );
    },
  );
}

class _GembaSearchablePickerSheet extends StatefulWidget {
  const _GembaSearchablePickerSheet({
    required this.title,
    required this.options,
    required this.searchHint,
    this.selectedValue,
  });

  final String title;
  final List<GembaPickerOption> options;
  final String? selectedValue;
  final String searchHint;

  @override
  State<_GembaSearchablePickerSheet> createState() =>
      _GembaSearchablePickerSheetState();
}

class _GembaSearchablePickerSheetState
    extends State<_GembaSearchablePickerSheet> {
  final _queryController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  List<GembaPickerOption> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options.where((o) {
      final haystack = [
        o.title,
        o.subtitle ?? '',
        o.leadingLabel ?? '',
        o.value,
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = media.size.height * 0.82;
    final filtered = _filtered;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _queryController,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _queryController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.clear_rounded),
                        ),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${filtered.length} option${filtered.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const _EmptySearch()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final option = filtered[index];
                        final selected = option.value == widget.selectedValue;
                        return _OptionTile(
                          option: option,
                          selected: selected,
                          onTap: () => Navigator.pop(context, option.value),
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

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final GembaPickerOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFCCFBF1) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFF5EEAD4)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              if (option.leadingLabel != null) ...[
                _CodeBadge(option.leadingLabel!),
                const SizedBox(width: 12),
              ] else
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF99F6E4)
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    selected
                        ? Icons.check_rounded
                        : Icons.chevron_right_rounded,
                    color: selected
                        ? GembaColors.brandPrimary
                        : const Color(0xFF64748B),
                    size: 20,
                  ),
                ),
              if (option.leadingLabel == null) const SizedBox(width: 12),
              Expanded(
                child: option.subtitle == null || option.subtitle!.isEmpty
                    ? Text(
                        option.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? GembaColors.ink
                              : const Color(0xFF0F172A),
                        ),
                      )
                    : Row(
                        children: [
                          Text(
                            option.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: selected
                                  ? GembaColors.ink
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              option.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              if (selected && option.leadingLabel != null)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: GembaColors.brandPrimary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeBadge extends StatelessWidget {
  const _CodeBadge(this.code);
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 58),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: GembaColors.brandPrimary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        code,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 42, color: Color(0xFF94A3B8)),
            SizedBox(height: 12),
            Text(
              'No matches',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Try a different code or name',
              style: TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}
