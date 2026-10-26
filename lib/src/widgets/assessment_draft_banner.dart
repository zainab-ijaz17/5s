import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/assessment_draft.dart';

class AssessmentDraftBanner extends StatelessWidget {
  const AssessmentDraftBanner({
    super.key,
    required this.draft,
    required this.onContinue,
    required this.onDiscard,
    this.compact = false,
  });

  final AssessmentDraft draft;
  final VoidCallback onContinue;
  final VoidCallback onDiscard;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final progress = (draft.progressFraction * 100).round();
    final updatedLabel =
        DateFormat('MMM d, h:mm a').format(draft.updatedAt.toLocal());
    final location = _locationLabel(draft);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDBA74)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.pending_actions,
                  color: Color(0xFFD97706),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Continue Previous Assessment',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9A3412),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      location,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF7C2D12),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Last saved $updatedLabel',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9A3412),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: draft.progressFraction.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFFFED7AA),
              color: const Color(0xFFEA580C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${draft.answeredCount} of ${draft.totalQuestions} questions answered ($progress%)',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9A3412),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDiscard,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF9A3412),
                    side: const BorderSide(color: Color(0xFFFDBA74)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Discard'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.play_arrow, size: 20),
                  label: const Text(
                    'Continue',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _locationLabel(AssessmentDraft draft) {
    final parts = <String>[draft.company];
    if (draft.bu != null && draft.bu!.isNotEmpty) parts.add(draft.bu!);
    if (draft.section != null && draft.section!.isNotEmpty) {
      parts.add(draft.section!);
    }
    return parts.join(' • ');
  }
}
