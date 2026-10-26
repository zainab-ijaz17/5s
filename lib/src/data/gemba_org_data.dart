/// Shared org selectors for Gemba Walk (aligned with 5S where applicable).

class GembaMachine {
  const GembaMachine({required this.code, required this.name});

  final String code;
  final String name;

  /// Unique value for dropdowns (codes can repeat across names).
  String get value => '$code|$name';

  String get label => '$code-$name';
}

class GembaOrgData {
  GembaOrgData._();

  static const List<String> companies = [
    'Packages Convertors Limited',
    // 'Packages Limited',
    // 'Bulleh Shah Packaging',
    // 'Tri-Pack',
    // 'DIC',
    // 'OmyaPack',
    // 'StarchPack',
    // 'Packages Mall',
  ];

  /// Form BU → SF division id (must match backend GEMBA_BU_DIVISIONS).
  static const Map<String, String> pclBuSfDivisionIds = {
    'BUFP': '20000044',
    // 'BUFC': '...',
    // 'BUCP': '...',
  };

  /// Form BUs with SF employee lookup configured on the backend.
  static const Set<String> pclBuEmployeeLookup = {
    'BUFP',
    // 'BUFC',
    // 'BUCP',
  };

  static bool hasEmployeeLookup(String? bu) {
    if (bu == null || bu.isEmpty) return false;
    return pclBuEmployeeLookup.contains(bu);
  }

  static const List<String> observationCategories = [
    'Safety',
    'Quality',
    'Electrical',
    'Mechanical',
    'WCM',
    'House keeping',
    'Operations',
    'Civil',
  ];

  /// Same structure as 5S Take Test for PCL, plus Finishing / Packing / Reproduction for BUFP machines.
  static const Map<String, List<String>> pclBuSections = {
    // 'BUFC': [
    //   'Folding & Gluing',
    //   'Offset Printing',
    //   'Roto Line',
    //   'Sorting & Breaking',
    // ],
    'BUFP': [
      'Printing',
      'Lamination',
      'Extrusion',
      'Slitting',
      'Finishing',
      'Packing',
      'Reproduction',
      'Mechanical Workshop',
      'Electrical Workshop',
    ],
    // 'BUCP': [
    //   'Facial Tissue',
    //   'Non-Tissue',
    //   'Tissue Roll',
    //   'PM-09',
    //   'FemCare',
    // ],
  };

  static const List<String> tripackBusinessUnits = [
    'PS5',
    'PS7',
    'MOPP',
    'MCPP',
    'CPP Slitters',
    'BOPP SS',
    'Erema',
    'CPP Lines',
    'BOPP Line 4',
    'BOPP Line 5',
    'Power House',
    'Utilities',
    'Store',
    'Waste Yard',
    'Dispatch & FG Hall',
    'Line-3',
    'E&I Workshop',
    'Utilities Workshop',
  ];

  /// Machines keyed by BUFP section name.
  static const Map<String, List<GembaMachine>> bufpMachinesBySection = {
    'Printing': [
      GembaMachine(code: '22233', name: 'ROTO PRINTING 10 COLOUR'),
      GembaMachine(code: '22268', name: 'ROTO PRINTING'),
      GembaMachine(code: '22279', name: 'ROTO PRINTING'),
      GembaMachine(code: '22297', name: 'ROTO PRINTING'),
      GembaMachine(code: '22114', name: 'FLEXO PRINTING 6-COLOUR'),
      GembaMachine(code: '22120', name: 'FLEXO PRINTING 8-COLOUR'),
      GembaMachine(code: '22140', name: 'FLEXO PRINTING 8-COLOUR'),
      GembaMachine(code: '22157', name: 'FLEXO PRINTING 8-COLOUR'),
      GembaMachine(code: '22150', name: 'Flexo Adhesive Label Printing'),
      GembaMachine(code: '22255', name: 'Rewinder'),
      GembaMachine(code: '22257', name: 'Rewinder'),
    ],
    'Lamination': [
      GembaMachine(code: '22226', name: 'Solvent base Laminator'),
      GembaMachine(code: '22294', name: 'Solvent base Laminator'),
      GembaMachine(code: '22224', name: 'Solvent less Laminator'),
      GembaMachine(code: '22266', name: 'Solvent less Laminator'),
      GembaMachine(code: '22271', name: 'Solvent less Laminator'),
      GembaMachine(code: '22267', name: 'Solvent less Laminator'),
      GembaMachine(code: '22278', name: 'Extrusion Laminator'),
    ],
    'Extrusion': [
      GembaMachine(code: '22215', name: 'EXTRUDER'),
      GembaMachine(code: '22217', name: 'EXTRUDER'),
      GembaMachine(code: '22234', name: 'EXTRUDER'),
      GembaMachine(code: '22238', name: 'EXTRUDER'),
      GembaMachine(code: '22274', name: 'EXTRUDER'),
      GembaMachine(code: '22296', name: 'EXTRUDER'),
      GembaMachine(code: '22218', name: 'Waxing'),
      GembaMachine(code: '22228', name: 'Waxing'),
      GembaMachine(code: '22272', name: 'Rewinder'),
    ],
    'Slitting': [
      GembaMachine(code: '22154', name: 'Slitter'),
      GembaMachine(code: '22155', name: 'Slitter'),
      GembaMachine(code: '22245', name: 'Slitter'),
      GembaMachine(code: '22237', name: 'Slitter'),
      GembaMachine(code: '22246', name: 'Slitter'),
      GembaMachine(code: '22247', name: 'Slitter'),
      GembaMachine(code: '22248', name: 'Slitter'),
      GembaMachine(code: '22249', name: 'Slitter'),
      GembaMachine(code: '22250', name: 'Slitter'),
      GembaMachine(code: '22270', name: 'Slitter'),
      GembaMachine(code: '22276', name: 'Slitter'),
      GembaMachine(code: '22280', name: 'Slitter'),
      GembaMachine(code: '22256', name: 'Rewinder'),
      GembaMachine(code: '22104', name: 'Rewinder'),
      GembaMachine(code: '22251', name: 'Rewinder'),
      GembaMachine(code: '22253', name: 'Rewinder'),
      GembaMachine(code: '22254', name: 'Rewinder'),
      GembaMachine(code: '22258', name: 'Rewinder'),
      GembaMachine(code: '22259', name: 'Rewinder'),
      GembaMachine(code: '22273', name: 'Rewinder'),
      GembaMachine(code: '22284', name: 'Rewinder'),
      GembaMachine(code: '22285', name: 'Rewinder'),
      GembaMachine(code: '22153', name: 'Rewinder'),
      GembaMachine(code: '22286', name: 'Rewinder'),
    ],
    'Finishing': [
      GembaMachine(code: '22124', name: 'Bag Making'),
      GembaMachine(code: '22138', name: 'Bag Making'),
      GembaMachine(code: '22152', name: 'Bag Making'),
      GembaMachine(code: '22265', name: 'Lid Punching'),
      GembaMachine(code: '22137', name: 'Cone Punching'),
      GembaMachine(code: '22139', name: 'Cone Punching'),
      GembaMachine(code: '22144', name: 'Cone Punching'),
      GembaMachine(code: '22117', name: 'CONE MAKING'),
      GembaMachine(code: '22119', name: 'CONE MAKING'),
      GembaMachine(code: '22136', name: 'CONE MAKING'),
      GembaMachine(code: '22147', name: 'CONE MAKING'),
      GembaMachine(code: '22148', name: 'CONE MAKING'),
      GembaMachine(code: '22149', name: 'CONE MAKING'),
      GembaMachine(code: '22151', name: 'CONE MAKING'),
      GembaMachine(code: '22209', name: 'CENTRE SEAL Tubing'),
      GembaMachine(code: '22295', name: 'CENTRE SEAL Tubing'),
      GembaMachine(code: '22264', name: 'EMBOSSING'),
      GembaMachine(code: '22262', name: 'Sleeve Cutting'),
      GembaMachine(code: '22235', name: 'Spout Inserting'),
      GembaMachine(code: '22240', name: 'Spout Inserting'),
      GembaMachine(code: '22281', name: 'Spout Inserting'),
      GembaMachine(code: '22239', name: 'Bag Making'),
      GembaMachine(code: '22207', name: 'Bag Making'),
      GembaMachine(code: '22269', name: 'Bag Making'),
      GembaMachine(code: '22275', name: 'Bag Making'),
      GembaMachine(code: '22277', name: 'Bag Making'),
      GembaMachine(code: '22283', name: 'CENTRE SEAL Bags'),
    ],
    'Packing': [
      GembaMachine(code: '22221', name: 'Packing'),
      GembaMachine(code: '22288', name: 'Packing'),
      GembaMachine(code: '22289', name: 'Packing'),
    ],
    'Reproduction': [
      GembaMachine(code: '22441', name: 'Old CFM machine'),
      GembaMachine(code: '22443', name: 'New CFM machine'),
      GembaMachine(code: '22470', name: 'Old chrome tank deatwyler'),
      GembaMachine(code: '22472', name: 'K-Walter Slim Line Chrome tank'),
      GembaMachine(code: '22420', name: 'Kodak Flexcel NX imager Photopolymer'),
      GembaMachine(code: '22430', name: 'Old copper tank deatwyler'),
      GembaMachine(code: '22431', name: 'Copper Galvo - Star 11-E'),
      GembaMachine(code: '22432', name: 'K-Walter Slim Line Copper tank'),
      GembaMachine(code: '22421', name: 'EDLF Unit'),
      GembaMachine(code: '22450', name: 'Mechanical Engraver - 304'),
      GembaMachine(code: '22453', name: 'Engraver Smart 5'),
      GembaMachine(code: '22455', name: 'Engraver K Smart 5 / 2'),
      GembaMachine(code: '22454', name: 'Engraver XL'),
      GembaMachine(code: '22121', name: 'Flexo Mounting 1320'),
      GembaMachine(code: '22423', name: 'New Flexo Mounting 1320'),
      GembaMachine(code: '22471', name: 'Finish Star Chorome (CR-Proof)'),
      GembaMachine(code: '22442', name: 'Finish star copper machine'),
      GembaMachine(code: '22462', name: 'K-Walter Slim Line Degreasing tank'),
      GembaMachine(code: '22463', name: 'Nickle tank'),
      GembaMachine(code: '22460', name: 'Old degreasing tank deatwyler'),
      GembaMachine(code: '22440', name: 'Polish master'),
      GembaMachine(code: '22480', name: 'Old Proof press'),
      GembaMachine(code: '22482', name: 'Proof Press'),
      GembaMachine(code: '22422', name: 'Relief Mate'),
      GembaMachine(code: '22421', name: 'Photopolymer Plate Processor'),
    ],
  };

  static List<GembaMachine> machinesForBuSection(String? bu, String? section) {
    if (bu != 'BUFP' || section == null || section.isEmpty) return const [];
    return bufpMachinesBySection[section] ?? const [];
  }
}
