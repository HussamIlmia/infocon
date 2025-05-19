import 'package:flutter/material.dart';
import 'main.dart';
import 'pages/login_page.dart';
import 'pages/management_dashboard_page.dart';
import 'components/inquiry_detail_page.dart';
import 'registration/cognito_service.dart';
import 'registration/company_registration.dart';
import 'registration/forgot_password.dart';
import 'registration/master_user_registration.dart';
import 'registration/product_key_registration.dart';
import 'pages/worker_document_page.dart';
import 'pages/register_worker_page.dart';
import 'pages/chat_link_management_page.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments;

    switch (settings.name) {
      case '/':
        return _fadeRoute(
          builder: (context) => FutureBuilder<bool>(
            future: CognitoService.instance.isUserSignedIn(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final isSignedIn = snapshot.data!;
              if (isSignedIn) {
                return FutureBuilder<String?>(
                  future: _fetchCompanyIdOrSignOut(),
                  builder: (context, snapshot2) {
                    if (!snapshot2.hasData) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final companyId = snapshot2.data;
                    if (companyId == null) {
                      return const HomeScreen();
                    } else {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        Navigator.pushReplacementNamed(
                          context,
                          '/console',
                          arguments: {'companyId': companyId},
                        );
                      });
                      return const SizedBox.shrink();
                    }
                  },
                );
              } else {
                return const HomeScreen();
              }
            },
          ),
          settings: settings,
        );

      case '/login':
        return _fadeRoute(
          builder: (context) => FutureBuilder<bool>(
            future: CognitoService.instance.isUserSignedIn(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final isSignedIn = snapshot.data!;
              if (isSignedIn) {
                return FutureBuilder<String?>(
                  future: _fetchCompanyIdOrSignOut(),
                  builder: (context, snapshot2) {
                    if (!snapshot2.hasData) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final companyId = snapshot2.data;
                    if (companyId == null) {
                      return const LoginScreen();
                    } else {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        Navigator.pushReplacementNamed(
                          context,
                          '/console',
                          arguments: {'companyId': companyId},
                        );
                      });
                      return const SizedBox.shrink();
                    }
                  },
                );
              } else {
                return const LoginScreen();
              }
            },
          ),
          settings: settings,
        );

      case '/forgotPassword':
        return _fadeRoute(
          builder: (_) => const ForgotPasswordScreen(),
          settings: settings,
        );

      case '/registrationKey':
        return _fadeRoute(
          builder: (_) => const RegistrationKeyScreen(),
          settings: settings,
        );

      case '/companyRegistration':
        if (args is String) {
          return _fadeRoute(
            builder: (_) => CompanyRegistrationScreen(registrationKey: args),
            settings: settings,
          );
        }
        return _errorRoute("No valid registrationKey for CompanyRegistration.");

      case '/masterUser':
        if (args is Map<String, dynamic>) {
          return _fadeRoute(
            builder: (_) => MasterUserCreationScreen(companyId: args['companyId']),
            settings: settings,
          );
        }
        return _errorRoute("Invalid arguments for MasterUserCreationScreen.");

      case '/console':
        if (args is Map<String, dynamic>) {
          return _fadeRoute(
            builder: (_) => ManagementDashboard(companyId: args['companyId']),
            settings: settings,
          );
        }
        return _errorRoute("No arguments provided for ManagementDashboard.");

      case '/inquiryDetail':
        if (args is Map<String, dynamic>) {
          return _fadeRoute(
            builder: (_) => InquiryDetailPage(
              companyId: args['companyId'],
              inquiryId: args['inquiryId'],
            ),
            settings: settings,
          );
        }
        return _errorRoute("No or invalid arguments for InquiryDetailPage.");

      case '/workerDocument':
        if (args is String) {
          return _fadeRoute(
            builder: (_) => WorkerDocumentPage(companyId: args),
            settings: settings,
          );
        }
        return _errorRoute("No or invalid arguments for WorkerDocumentPage.");

      case '/registerWorker':
        if (args is String) {
          return _fadeRoute(
            builder: (_) => RegisterWorkerPage(companyId: args),
            settings: settings,
          );
        }
        return _errorRoute("No or invalid arguments for RegisterWorkerPage.");

      case '/ChatLinkManagement':
        if (args is String) {
          return _fadeRoute(
            builder: (_) => ChatLinkManagementPage(companyId: args),
            settings: settings,
          );
        }
        return _errorRoute("No or invalid arguments for ChatLinkManagementPage.");

      default:
        return _errorRoute("Page not found: ${settings.name}");
    }
  }

  /// Replaces the standard MaterialPageRoute with a custom fade transition.
  static PageRoute _fadeRoute({
    required WidgetBuilder builder,
    required RouteSettings settings,
  }) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionDuration: const Duration(milliseconds: 300), // Adjust as desired
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Fade from 0.0 to 1.0
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  static Future<String?> _fetchCompanyIdOrSignOut() async {
    try {
      final attrs = await CognitoService.instance.getUserAttributes();
      String? companyId;
      for (var attr in attrs) {
        if (attr.userAttributeKey.key == 'custom:companyid') {
          companyId = attr.value;
          break;
        }
      }
      if (companyId == null) {
        await CognitoService.instance.signOut();
        return null;
      }
      return companyId;
    } catch (e) {
      await CognitoService.instance.signOut();
      return null;
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return _fadeRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(message)),
      ),
      settings: const RouteSettings(name: "ErrorRoute"),
    );
  }
}
