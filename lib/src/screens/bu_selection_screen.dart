import 'package:flutter/material.dart';
import '../../routes.dart';

class BUSelectionScreen extends StatelessWidget {
  const BUSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E40AF),
        elevation: 0,
        title: const Text(
          'Select Business Unit',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Choose your Business Unit',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Select the Business Unit you manage',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // BUFC Option
              _buildBUOption(
                context,
                'BUFC',
                'Business Unit - Folding Cartons',
                const Color(0xFF059669),
                Icons.account_balance,
              ),
              const SizedBox(height: 16),
              // BUCP Option
              _buildBUOption(
                context,
                'BUCP',
                'Business Unit - Consumer Products',
                const Color(0xFF0891B2),  
                Icons.business_center,
              ),
              const SizedBox(height: 16),
              // BUFP Option
              _buildBUOption(
                context,
                'BUFP',
                'Business Unit - Flexible Packaging',
                const Color(0xFFDC2626),
                Icons.factory,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBUOption(
    BuildContext context,
    String buCode,
    String description,
    Color color,
    IconData icon,
  ) {
    return Card(
      elevation: 4,
      shadowColor: color.withOpacity(0.2),
      child: InkWell(
        onTap: () {
          Navigator.pushReplacementNamed(
            context,
            Routes.buManagerDashboard,
            arguments: {
              'buCode': buCode,
              'buName': description,
            },
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.05),
                color.withOpacity(0.1),
              ],
            ),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 30,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      buCode,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: color.withOpacity(0.6),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
