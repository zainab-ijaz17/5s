// lib/src/util/assessment_recipients.dart
class AssessmentRecipients {
  /// Temporary testing: ALL assessments go only to these two addresses,
  /// regardless of company / BU / section. Restore production map when done.
  static const List<String> temporaryRecipients = [
    'anasbabar404@gmail.com',
    // 'usman.muhammad@packages.com.pk',
  ];

  /*
  static const List<String> _bufpRecipients = [
    'tooba.shahid@packages.com.pk',
    'iftikhar.alam@packages.com.pk',
    'usman.muhammad@packages.com.pk',
    'hafiz.yousaf@packages.com.pk',
  ];

  static const Map<String, Map<String, List<String>>> _recipientMap = {
    'BUCP': {
      'Facial Tissue': [
        'manahill.iftikhar@packages.com.pk',
        'Muaz.Hashmi@packages.com.pk',
        'usman.muhammad@packages.com.pk',
      ],
      'Non-Tissue': [
        'manahill.iftikhar@packages.com.pk',
        'Muaz.Hashmi@packages.com.pk',
        'usman.muhammad@packages.com.pk',
      ],
      'Tissue Roll': [
        'manahill.iftikhar@packages.com.pk',
        'Muaz.Hashmi@packages.com.pk',
        'usman.muhammad@packages.com.pk',
      ],
      'PM-09': [
        'aansa.batool@packages.com.pk',
        'shoaib.riasat@packages.com.pk',
        'hammad.razaq@packages.com.pk',
        'usman.muhammad@packages.com.pk',
      ],
      'FemCare': [
        'nimra.areeb@packages.com.pk',
        'muhammad.zeeshan@packages.com.pk',
        'usman.muhammad@packages.com.pk',
      ],
    },
    'BUFC': {
      'Folding & Gluing': [
        'aliza.imam@packages.com.pk',
        'daud.jabran@packages.com.pk',
      ],
      'Offset Printing': [
        'aliza.imam@packages.com.pk',
        'daud.jabran@packages.com.pk',
      ],
      'Roto Line': [
        'aliza.imam@packages.com.pk',
        'daud.jabran@packages.com.pk',
      ],
      'Sorting & Breaking': [
        'aliza.imam@packages.com.pk',
        'daud.jabran@packages.com.pk',
      ],
      // Legacy label kept for older saved assessments
      'FG& paper Cup': [
        'aliza.imam@packages.com.pk',
        'daud.jabran@packages.com.pk',
      ],
    },
    'BUFP': {
      'Printing': _bufpRecipients,
      'Lamination': _bufpRecipients,
      'Extrusion': _bufpRecipients,
      'Slitting': _bufpRecipients,
      'Mechanical Workshop': _bufpRecipients,
      'Electrical Workshop': _bufpRecipients,
    },
  };
  */

  static List<String> getRecipients(String? bu, String? section) {
    return List<String>.from(temporaryRecipients);

    /*
    if (bu == null) return [];
    final buMap = _recipientMap[bu];
    if (buMap == null) return [];

    if (section == null || section.isEmpty) {
      return getAllRecipientsForBU(bu);
    }

    final exact = buMap[section];
    if (exact != null) return List<String>.from(exact);

    final normalized = _normalizeSection(section);
    for (final entry in buMap.entries) {
      if (_normalizeSection(entry.key) == normalized) {
        return List<String>.from(entry.value);
      }
    }

    return [];
    */
  }

  // static String _normalizeSection(String value) =>
  //     value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static List<String> getAllRecipientsForBU(String? bu) {
    return List<String>.from(temporaryRecipients);

    /*
    if (bu == null) return [];
    final sections = _recipientMap[bu]?.values.toList() ?? [];
    return sections.expand((emails) => emails).toSet().toList();
    */
  }
}
