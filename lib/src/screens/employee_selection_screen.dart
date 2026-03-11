import 'package:flutter/material.dart';
import '../../routes.dart';

class EmployeeSelectionScreen extends StatelessWidget {
  const EmployeeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Select Employee',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.cyan[600],
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Header section with gradient
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.cyan[600]!,
                  Colors.cyan[700]!,
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Choose Employee for Assessment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select an employee to begin the 5S assessment',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          
          // Employee list
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  _buildEmployeeCard(
                    context,
                    'John Smith',
                    'Production Manager',
                    'Manufacturing Department',
                    Icons.engineering,
                    Colors.blue[100]!,
                  ),
                  const SizedBox(height: 12),
                  _buildEmployeeCard(
                    context,
                    'Sarah Johnson',
                    'Quality Inspector',
                    'Quality Control Department',
                    Icons.verified_user,
                    Colors.green[100]!,
                  ),
                  const SizedBox(height: 12),
                  _buildEmployeeCard(
                    context,
                    'Mike Davis',
                    'Floor Supervisor',
                    'Operations Department',
                    Icons.supervisor_account,
                    Colors.orange[100]!,
                  ),
                  const SizedBox(height: 12),
                  _buildEmployeeCard(
                    context,
                    'Lisa Chen',
                    'Safety Coordinator',
                    'Health & Safety Department',
                    Icons.health_and_safety,
                    Colors.red[100]!,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(
    BuildContext context,
    String name,
    String position,
    String department,
    IconData icon,
    Color iconBackgroundColor,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(context, Routes.assessment),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Employee icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  icon,
                  color: Colors.cyan[700],
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              
              // Employee details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      position,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.cyan[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      department,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow icon
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
