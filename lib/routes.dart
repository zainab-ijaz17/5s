import 'package:flutter/material.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/company_selection_screen.dart';
import 'src/screens/bu_selection_screen.dart';
import 'src/screens/take_test_screen.dart';
import 'src/screens/assessment_screen.dart';
import 'src/screens/assessment_results_screen.dart';
import 'src/screens/splash_screen.dart';
import 'src/screens/manage_questions_screen.dart';
import 'src/screens/manage_companies_screen.dart';
import 'src/screens/analytics_screen.dart';
import 'src/screens/power_user_dashboard_screen.dart';
import 'src/screens/bu_manager_dashboard_screen.dart';
import 'src/screens/observations_screen.dart'; // add observations screen import
import 'src/screens/assessment_history_screen.dart';
import 'src/screens/previous_assessments_screen.dart';
import 'src/screens/failed_audits_screen.dart';
import 'src/screens/flagged_employees_screen.dart';
import 'src/screens/edit_assessments_screen.dart';
import 'src/screens/resolved_assessments_screen.dart';

class Routes {
  static const String splash = '/';
  static const String login = '/login';
  static const String companies = '/companies';
  static const String buSelection = '/bu-selection';
  static const String takeTest = '/take-test';
  static const String assessment = '/assessment';
  static const String admin = '/admin';
  static const String assessmentResults = '/assessmentResults';
  static const String powerUser = '/power-user';
  static const String adminQuestions = '/admin-questions';
  static const String manageCompanies = '/manage-companies';
  static const String analytics = '/analytics';
  static const String businessSelection = '/business-selection';
  static const String businessDashboard = '/business-dashboard';
  static const String buManagerDashboard = '/bu-manager-dashboard';
  static const String manageQuestions = '/manage-questions';
  static const String observations = '/observations'; // new route
  static const String assessmentHistory = '/assessment-history';
  static const String previousAssessments = '/previous-assessments';
  static const String failedAudits = '/failed-audits';
  static const String flaggedEmployees = '/flagged-employees';
  static const String editAssessments = '/edit-assessments';
  static const String passedAssessments = '/passed-assessments';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      splash: (context) => const SplashScreen(),
      login: (context) => const LoginScreen(),
      companies: (context) => const CompanySelectionScreen(),
      buSelection: (context) => const BUSelectionScreen(),
      takeTest: (context) => const TakeTestScreen(),
      assessment: (context) => const AssessmentScreen(),
      assessmentResults: (context) => const AssessmentResultsScreen(),
      powerUser: (context) => const PowerUserDashboardScreen(),
      manageCompanies: (context) => const ManageCompaniesScreen(),
      analytics: (context) => const AnalyticsScreen(),
      buManagerDashboard: (context) => const BUManagerDashboardScreen(),
      manageQuestions: (_) => const ManageQuestionsScreen(),
      observations: (context) => const ObservationsScreen(), // register route
      assessmentHistory: (context) => const AssessmentHistoryScreen(),
      previousAssessments: (context) => const PreviousAssessmentsScreen(),
      failedAudits: (context) => const FailedAuditsScreen(),
      flaggedEmployees: (context) => const FlaggedEmployeesScreen(),
      editAssessments: (context) => const EditAssessmentsScreen(),
      passedAssessments: (context) => const PassedAssessmentsScreen(),
    };
  }
}
