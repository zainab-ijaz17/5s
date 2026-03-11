import 'package:flutter/material.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final List<Map<String, dynamic>> buData = [
    {
      'name': 'Manufacturing BU',
      'completion': 85,
      'totalAssessments': 45,
      'completedAssessments': 38,
      'flaggedItems': 12,
      'companies': ['Company A', 'Company B'],
    },
    {
      'name': 'Operations BU',
      'completion': 92,
      'totalAssessments': 32,
      'completedAssessments': 29,
      'flaggedItems': 5,
      'companies': ['Company C'],
    },
    {
      'name': 'Quality BU',
      'completion': 67,
      'totalAssessments': 28,
      'completedAssessments': 19,
      'flaggedItems': 18,
      'companies': ['Company A', 'Company D'],
    },
    {
      'name': 'Safety BU',
      'completion': 78,
      'totalAssessments': 35,
      'completedAssessments': 27,
      'flaggedItems': 8,
      'companies': ['Company B', 'Company C', 'Company D'],
    },
  ];

  String selectedFilter = 'All Time';
  DateTimeRange? selectedDateRange;
  String selectedSection = 'All Sections';

  final List<Map<String, dynamic>> assessments = [
    // demo-level rows; in real app these would come from backend
    {
      'date': DateTime(2025, 9, 1),
      'bu': 'BUFC',
      'section': 'Folding & Gluing',
      'audits': 3,
      'score': 86,
      'average': 82.5,
      'observations': 4,
    },
    {
      'date': DateTime(2025, 9, 5),
      'bu': 'BUFP',
      'section': 'Extrusion',
      'audits': 2,
      'score': 90,
      'average': 87.0,
      'observations': 2,
    },
    {
      'date': DateTime(2025, 9, 9),
      'bu': 'BUFC',
      'section': 'Offset Printing',
      'audits': 5,
      'score': 80,
      'average': 79.0,
      'observations': 6,
    },
  ];

  List<String> get allSections {
    final set = <String>{};
    for (final bu in buData) {
      // if sections known per BU, merge; we’ll add a static set here as demo
    }
    return [
      'All Sections',
      'Folding & Gluing',
      'Finished Goods',
      'Offset Printing',
      'Roto Line',
      'Printing',
      'Lamination',
      'Extrusion',
      'Slitting',
    ];
  }

  List<Map<String, dynamic>> get filteredAssessments {
    return assessments.where((row) {
      final matchesSection = selectedSection == 'All Sections' || row['section'] == selectedSection;
      final matchesDate = selectedDateRange == null ||
          (row['date'] as DateTime).isAfter(selectedDateRange!.start.subtract(const Duration(days: 1))) &&
              (row['date'] as DateTime).isBefore(selectedDateRange!.end.add(const Duration(days: 1)));
      return matchesSection && matchesDate;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Analytics Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF059669),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilters(),
            const SizedBox(height: 24),
            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Overall Completion',
                    '80.5%',
                    Icons.trending_up,
                    const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'Total Flagged',
                    '43',
                    Icons.flag,
                    const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Active BUs',
                    '4',
                    Icons.business_center,
                    const Color(0xFF0891B2),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'Total Assessments',
                    '140',
                    Icons.assignment,
                    const Color(0xFF7C3AED),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // BU Analytics
            Text(
              'Business Unit Analytics',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: buData.length,
              itemBuilder: (context, index) {
                final bu = buData[index];
                return _buildBUCard(bu);
              },
            ),
            const SizedBox(height: 32),

            Text(
              'Assessments',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildAssessmentsTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBUCard(Map<String, dynamic> bu) {
    final completion = bu['completion'] as int;
    final flagged = bu['flaggedItems'] as int;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                bu['name'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (flagged > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$flagged Flagged',
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Completion Rate',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '$completion%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: completion / 100,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  completion >= 80 ? const Color(0xFF10B981) : 
                  completion >= 60 ? const Color(0xFFF59E0B) : 
                  const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Statistics Row
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Completed',
                  '${bu['completedAssessments']}/${bu['totalAssessments']}',
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Companies',
                  '${(bu['companies'] as List).length}',
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Companies List
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: (bu['companies'] as List<String>).map((company) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  company,
                  style: const TextStyle(
                    color: Color(0xFF059669),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Column(
      children: [
        _buildDateFilter(),
        const SizedBox(height: 12),
        _buildSectionFilter(),
      ],
    );
  }

  Widget _buildDateFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(
          children: [
            Icon(Icons.filter_list, color: Color(0xFF059669), size: 20),
            SizedBox(width: 8),
            Text(
              'Filter by Date',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _chip('All Time', () {
              setState(() {
                selectedFilter = 'All Time';
                selectedDateRange = null;
              });
            }, isSelected: selectedFilter == 'All Time'),
            _chip('Last 7 Days', () {
              setState(() {
                selectedFilter = 'Last 7 Days';
                selectedDateRange = DateTimeRange(
                  start: DateTime.now().subtract(const Duration(days: 7)),
                  end: DateTime.now(),
                );
              });
            }, isSelected: selectedFilter == 'Last 7 Days'),
            _chip('Last 30 Days', () {
              setState(() {
                selectedFilter = 'Last 30 Days';
                selectedDateRange = DateTimeRange(
                  start: DateTime.now().subtract(const Duration(days: 30)),
                  end: DateTime.now(),
                );
              });
            }, isSelected: selectedFilter == 'Last 30 Days'),
            _customRangeChip(),
          ],
        ),
        if (selectedDateRange != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.date_range, size: 16, color: Color(0xFF059669)),
              const SizedBox(width: 8),
              Text(
                '${selectedDateRange!.start.day}/${selectedDateRange!.start.month}/${selectedDateRange!.start.year} - '
                '${selectedDateRange!.end.day}/${selectedDateRange!.end.month}/${selectedDateRange!.end.year}',
                style: const TextStyle(color: Color(0xFF059669), fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    selectedDateRange = null;
                    selectedFilter = 'All Time';
                  });
                },
                child: const Icon(Icons.close, size: 16, color: Color(0xFF059669)),
              ),
            ],
          ),
        ],
      ]),
    );
  }

  Widget _buildSectionFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.category_outlined, color: Color(0xFF059669), size: 20),
          const SizedBox(width: 8),
          const Text('Section', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedSection,
                isExpanded: true,
                items: allSections
                    .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (val) => setState(() => selectedSection = val ?? 'All Sections'),
              ),
            ),
          ),
          if (selectedSection != 'All Sections')
            TextButton(
              onPressed: () => setState(() => selectedSection = 'All Sections'),
              child: const Text('Clear'),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap, {bool isSelected = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF059669) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF059669) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _customRangeChip() {
    return GestureDetector(
      onTap: () async {
        final DateTimeRange? picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          initialDateRange: selectedDateRange,
        );
        if (picked != null) {
          setState(() {
            selectedDateRange = picked;
            selectedFilter = 'Custom Range';
          });
        }
      },
      child: _chip('Custom Range', () {}, isSelected: selectedFilter == 'Custom Range'),
    );
  }

  Widget _buildAssessmentsTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: filteredAssessments.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
        itemBuilder: (_, i) {
          final row = filteredAssessments[i];
          final date = row['date'] as DateTime;
          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.assignment_turned_in, color: Color(0xFF059669), size: 20),
            ),
            title: Text(
              '${row['bu']} • ${row['section']}',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
            subtitle: Text(
              'Assessment Date: ${date.day}/${date.month}/${date.year}',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Audits: ${row['audits']}', style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
                Text('Score: ${row['score']} | Avg: ${row['average']}',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                Text('Observations: ${row['observations']}',
                    style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            onTap: () {
              // In the future: navigate to detailed assessment
            },
          );
        },
      ),
    );
  }
}
