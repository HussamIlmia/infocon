import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';

/// A centralized service for AWS Cognito operations.
class CognitoService {
  // Singleton
  CognitoService._privateConstructor();
  static final CognitoService instance = CognitoService._privateConstructor();

  // ---------------------------------------------------------------------------
  // 1) SIGN UP a user with custom:companyId
  // ---------------------------------------------------------------------------
  /// Sign up a user with [username] (often email), [password], [email],
  /// plus custom:companyId as a custom attribute if your user pool
  /// is configured with "companyId" as a custom attribute.
  Future<SignUpResult> signUpUser({
    required String username,
    required String password,
    required String email,
    required String companyId,
  }) async {
    try {
      final userAttributes = {
        CognitoUserAttributeKey.email: email,
        // Ensure your user pool has a custom attribute "companyId"
        CognitoUserAttributeKey.parse('custom:companyId'): companyId,
      };

      final res = await Amplify.Auth.signUp(
        username: username,
        password: password,
        options: SignUpOptions(userAttributes: userAttributes),
      );
      return res;
    } on AuthException catch (e) {
      safePrint('SignUp error: ${e.message}');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 2) CONFIRM SIGN UP (via emailed or SMS code)
  // ---------------------------------------------------------------------------
  Future<bool> confirmSignUp({
    required String username,
    required String confirmationCode,
  }) async {
    try {
      final result = await Amplify.Auth.confirmSignUp(
        username: username,
        confirmationCode: confirmationCode,
      );
      return result.isSignUpComplete;
    } on AuthException catch (e) {
      safePrint('ConfirmSignUp error: ${e.message}');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 3) RESEND CONFIRMATION CODE
  // ---------------------------------------------------------------------------
  Future<void> resendCode(String username) async {
    try {
      await Amplify.Auth.resendSignUpCode(username: username);
    } on AuthException catch (e) {
      safePrint('Resend code error: ${e.message}');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 4) SIGN IN (LOGIN) + Retrieve Session Tokens
  // ---------------------------------------------------------------------------
  /// Sign in a user with [username] & [password]. On success, session tokens
  /// are automatically stored in secure storage (mobile) or IndexedDB (web).
  /// Returns the [SignInResult].
  Future<SignInResult> signInUser({
    required String username,
    required String password,
  }) async {
    try {
      final result = await Amplify.Auth.signIn(
        username: username,
        password: password,
      );
      return result;
    } on AuthException catch (e) {
      safePrint('SignIn error: ${e.message}');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 5) FETCH SESSION TOKENS (ID Token, Access Token, Refresh Token)
  // ---------------------------------------------------------------------------
  /// Example method to get the current [CognitoAuthSession].
  /// If you need the raw tokens, cast to [CognitoAuthSession] and read them.
  Future<CognitoAuthSession> fetchSession() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession() 
          as CognitoAuthSession;
      return session;
    } on AuthException catch (e) {
      safePrint('FetchSession error: ${e.message}');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 6) CHECK IF USER IS SIGNED IN
  // ---------------------------------------------------------------------------
  /// Returns `true` if there's a valid session. 
  Future<bool> isUserSignedIn() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      return session.isSignedIn;
    } on AuthException catch (e) {
      safePrint('isUserSignedIn error: ${e.message}');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // 7) GET USER ATTRIBUTES (like custom:companyId)
  // ---------------------------------------------------------------------------
  /// Retrieve user attributes from the currently signed-in user,
  /// e.g. email, custom:companyId, etc.
  Future<List<AuthUserAttribute>> getUserAttributes() async {
    try {
      final attrs = await Amplify.Auth.fetchUserAttributes();
      return attrs;
    } on AuthException catch (e) {
      safePrint('FetchAttrs error: ${e.message}');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 8) RESET PASSWORD (Forgot Password) Step 1
  // ---------------------------------------------------------------------------
  /// Request a password reset code. Cognito will email or SMS the user.
  Future<void> resetPassword(String username) async {
    try {
      await Amplify.Auth.resetPassword(username: username);
    } on AuthException catch (e) {
      safePrint('ResetPassword error: ${e.message}');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 9) CONFIRM RESET PASSWORD (Forgot Password) Step 2
  // ---------------------------------------------------------------------------
  /// Submit the [confirmationCode] from email/SMS and a [newPassword]
  /// to finish resetting the user's password.
  Future<void> confirmResetPassword(
    String username,
    String confirmationCode,
    String newPassword,
  ) async {
    try {
      await Amplify.Auth.confirmResetPassword(
        username: username,
        newPassword: newPassword,
        confirmationCode: confirmationCode,
      );
    } on AuthException catch (e) {
      safePrint('ConfirmResetPassword error: ${e.message}');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 10) SIGN OUT
  // ---------------------------------------------------------------------------
  /// Sign out the currently logged-in user, clearing tokens locally.
  Future<void> signOut() async {
    try {
      await Amplify.Auth.signOut();
    } on AuthException catch (e) {
      safePrint('SignOut error: ${e.message}');
      rethrow;
    }
  }
}
