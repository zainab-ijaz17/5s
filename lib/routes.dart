import 'package:flutter/material.dart';
import 'src/screens/app_chooser_screen.dart';
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
import 'src/screens/gemba/gemba_home_screen.dart';
import 'src/screens/gemba/gemba_login_screen.dart';
import 'src/skill_matrix/screens/skill_matrix_home_screen.dart';
import 'src/skill_matrix/screens/skill_matrix_manager_assessments_screen.dart';
import 'src/skill_matrix/screens/skill_matrix_manager_home_screen.dart';
import 'src/skill_matrix/screens/skill_matrix_manager_review_screen.dart';
import 'src/skill_matrix/screens/skill_matrix_manager_skill_matrix_screen.dart';
import 'src/skill_matrix/screens/skill_matrix_role_screen.dart';
import 'src/skill_matrix/screens/skill_matrix_worker_assessments_screen.dart';
import 'src/skill_matrix/screens/skill_matrix_worker_rate_skill_screen.dart';
import 'src/skill_matrix/screens/skill_matrix_et_add_skill_screen.dart';

class Routes {
  static const String splash = '/';
  static const String appChooser = '/apps';
  static const String login = '/login';
  static const String gembaLogin = '/gemba/login';
  static const String gembaHome = '/gemba/home';
  static const String skillMatrixRole = '/skill-matrix/role';
  static const String skillMatrixHome = '/skill-matrix/home';
  static const String skillMatrixManagerReview = '/skill-matrix/manager/review';
  static const String skillMatrixManagerSkillMatrix =
      '/skill-matrix/manager/skill-matrix';
  static const String skillMatrixManagerAssessments =
      '/skill-matrix/manager/assessments';
  static const String skillMatrixWorkerRateSkill = '/skill-matrix/worker/rate-skill';
  static const String skillMatrixWorkerAssessments =
      '/skill-matrix/worker/assessments';
  static const String skillMatrixEtAddSkill = '/skill-matrix/et/add-skill';
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
      appChooser: (context) => const AppChooserScreen(),
      login: (context) => const LoginScreen(),
      gembaLogin: (context) => const GembaLoginScreen(),
      gembaHome: (context) => const GembaHomeScreen(),
      skillMatrixRole: (context) => const SkillMatrixRoleScreen(),
      skillMatrixHome: (context) => const SkillMatrixHomeScreen(),
      skillMatrixManagerReview: (context) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is Map) {
          return SkillMatrixManagerReviewScreen(
            employeeId: args['employeeId']?.toString() ?? '',
            workerUserId: args['userId']?.toString() ?? '',
          );
        }
        final id = args as String? ?? '';
        return SkillMatrixManagerReviewScreen(employeeId: id);
      },
      skillMatrixManagerSkillMatrix: (context) =>
          const SkillMatrixManagerSkillMatrixScreen(),
      skillMatrixManagerAssessments: (context) =>
          const SkillMatrixManagerAssessmentsScreen(),
      skillMatrixWorkerRateSkill: (context) =>
          const SkillMatrixWorkerRateSkillScreen(),
      skillMatrixWorkerAssessments: (context) =>
          const SkillMatrixWorkerAssessmentsScreen(),
      skillMatrixEtAddSkill: (context) => const SkillMatrixEtAddSkillScreen(),
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
