import 'package:flutter/material.dart';
import '../api/tos_html_screen.dart';
import '../api/tos_service.dart';
import '../registration/cognito_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _errorMessage;
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _attemptLogin() async {
    final email = _emailController.text.trim();
    final pw = _passwordController.text.trim();

    if (email.isEmpty || pw.isEmpty) {
      setState(() {
        _errorMessage = 'メールアドレスとパスワードを両方入力してください。';
      });
      return;
    }

    setState(() => _errorMessage = null);

    try {
      // 1) Sign in user via Cognito
      final signInRes = await CognitoService.instance.signInUser(
        username: email,
        password: pw,
      );

      if (signInRes.isSignedIn) {
        final attrs = await CognitoService.instance.getUserAttributes();
        String? companyId;
        String? cognitoSub;

        for (var attr in attrs) {
          if (attr.userAttributeKey.key == 'sub') {
            cognitoSub = attr.value;
          }
          if (attr.userAttributeKey.key == 'custom:companyid') {
            companyId = attr.value;
          }
        }

        // 2) If we have a user ID, check TOS
        if (cognitoSub != null) {
          final accepted = await _checkAndMaybeAcceptTOS(cognitoSub);
          if (!accepted) {
            // If TOS is rejected or an error occurs, sign out user
            await CognitoService.instance.signOut();
            setState(() {
              _errorMessage = '利用規約に同意いただけないため、ログインできません。';
            });
            return;
          }
        } else {
          // No sub found => sign out
          await CognitoService.instance.signOut();
          setState(() => _errorMessage = 'ユーザーIDが見つかりません。');
          return;
        }

        // 3) If TOS accepted, go to dashboard if we have a companyId
        if (companyId != null) {
          _goToDashboard(companyId: companyId);
        } else {
          await CognitoService.instance.signOut();
          setState(() => _errorMessage = 'companyIdが見つかりませんでした。');
        }
      } else {
        setState(() {
          _errorMessage =
              'ログインに失敗しました。メールアドレスまたはパスワードが正しいか確認してください。';
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'ログインエラー: $e');
    }
  }

  Future<bool> _checkAndMaybeAcceptTOS(String userId) async {
    try {
      final checkResponse = await TOSService.checkDocument(
        appId: 'console',
        userId: userId,
        docType: 'TOS',
      );

      final needsToAccept = checkResponse['needsToAccept'] as bool? ?? false;
      final latestVersion = checkResponse['latestVersion'] as int? ?? 0;
      final htmlContent = checkResponse['htmlContent'] as String?;

      if (!needsToAccept) {
        return true;
      }

      if (htmlContent == null) {
        setState(() => _errorMessage = '利用規約を読み込めませんでした。');
        return false;
      }

      // Show the TOS dialog using our new helper and wait for the user's response.
      final accepted = await showTOSDialog(
        context: context,
        htmlContent: htmlContent,
        userId: userId,
        latestVersion: latestVersion,
      );

      return accepted == true;
    } catch (e) {
      setState(() => _errorMessage = 'TOS確認エラー: $e');
      return false;
    }
  }

  void _goToDashboard({required String companyId}) {
    Navigator.pushReplacementNamed(
      context,
      '/console',
      arguments: {
        'companyId': companyId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeIn,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage('assets/images/hero_image.png'),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primaryContainer.withAlpha(50),
                    colorScheme.primaryContainer.withAlpha(100),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 24,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Card(
                          elevation: 4,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'ログイン',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onPrimaryContainer,
                                      ),
                                ),
                                const SizedBox(height: 24),
                                // Email field
                                TextField(
                                  controller: _emailController,
                                  decoration: const InputDecoration(
                                    labelText: 'メールアドレス',
                                    hintText: 'example@mail.com',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Password field
                                TextField(
                                  controller: _passwordController,
                                  decoration: const InputDecoration(
                                    labelText: 'パスワード',
                                    border: OutlineInputBorder(),
                                  ),
                                  obscureText: true,
                                ),
                                if (_errorMessage != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ],
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _attemptLogin,
                                  icon: const Icon(
                                    Icons.lock_open,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  label: const Text('ログイン'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/forgotPassword');
                                  },
                                  child: const Text(
                                    'パスワードをお忘れですか？',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
