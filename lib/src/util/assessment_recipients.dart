// lib/src/util/assessment_recipients.dart
class AssessmentRecipients {
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
      'Offset Printing': [
        'aliza.imam@packages.com.pk',
        'daud.jabran@packages.com.pk',
      ],
      'FG& paper Cup': [
        'aliza.imam@packages.com.pk',
        'daud.jabran@packages.com.pk',
      ],
      'Roto Line': [
        'aliza.imam@packages.com.pk',
        'daud.jabran@packages.com.pk',
      ],
    },
    'BUFP': {
      'Printing': [
        'tooba.shahid@packages.com.pk',
        'iftikhar.alam@packages.com.pk',
        'usman.muhammad@packages.com.pk',
      ],
      'Lamination': [
        'tooba.shahid@packages.com.pk',
        'iftikhar.alam@packages.com.pk',
        'usman.muhammad@packages.com.pk',
      ],
      'Extrusion': [
        'tooba.shahid@packages.com.pk',
        'iftikhar.alam@packages.com.pk',
        'usman.muhammad@packages.com.pk',
      ],
      'Slitting': [
        'tooba.shahid@packages.com.pk',
        'iftikhar.alam@packages.com.pk',
        'usman.muhammad@packages.com.pk',
      ],
    },
  };

  static List<String> getRecipients(String? bu, String? section) {
    if (bu == null || section == null) return [];
    return _recipientMap[bu]?[section] ?? [];
  }

  static List<String> getAllRecipientsForBU(String? bu) {
    if (bu == null) return [];
    final sections = _recipientMap[bu]?.values.toList() ?? [];
    return sections.expand((emails) => emails).toSet().toList();
  }
}
