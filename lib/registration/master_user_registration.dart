import 'package:flutter/material.dart';
import 'cognito_service.dart';

class MasterUserCreationScreen extends StatefulWidget {
  final String companyId; // read-only, passed from prior screen

  const MasterUserCreationScreen({
    super.key,
    required this.companyId,
  });

  @override
  State<MasterUserCreationScreen> createState() =>
      _MasterUserCreationScreenState();
}

class _MasterUserCreationScreenState extends State<MasterUserCreationScreen>
    with SingleTickerProviderStateMixin {
  // Email & password fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  final TextEditingController _pwConfirmController = TextEditingController();

  // For the verification code step
  final TextEditingController _verificationCodeController =
      TextEditingController();

  bool _isRegistering = false;
  bool _isSuccess = false;
  bool _awaitingConfirmationCode = false; // if user must enter email code
  String? _errorMessage; // show any validation or API error in Japanese

  // Fade-in animation
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
    super.dispose();
  }

  /// Sign up the master user in Cognito, using [email] as the Cognito username,
  /// and storing [companyId] as a custom attribute: "custom:companyId".
  Future<void> _signUpMasterUser() async {
    final email = _emailController.text.trim();
    final pw = _pwController.text.trim();
    final pwConfirm = _pwConfirmController.text.trim();

    // --- Basic validation in Japanese ---
    if (email.isEmpty) {
      setState(() => _errorMessage = 'メールアドレスを入力してください。');
      return;
    }
    if (pw.isEmpty || pwConfirm.isEmpty) {
      setState(() => _errorMessage = 'パスワードと確認用パスワードを入力してください。');
      return;
    }
    if (pw != pwConfirm) {
      setState(() => _errorMessage = 'パスワードが一致しません。');
      return;
    }

    setState(() {
      _isRegistering = true;
      _errorMessage = null;
    });

    try {
      // We'll use the email as the "username" for Cognito.
      // This will also store "custom:companyId" in the user pool.
      final signUpResult = await CognitoService.instance.signUpUser(
        username: email, // same as email
        password: pw,
        email: email,
        companyId: widget.companyId,
      );

      if (signUpResult.isSignUpComplete) {
        // Possibly auto-confirmed by the pool
        setState(() {
          _isSuccess = true;
          _awaitingConfirmationCode = false;
        });
      } else {
        // They need to confirm the code from email
        setState(() => _awaitingConfirmationCode = true);
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isRegistering = false);
    }
  }

  /// Confirm the sign-up by entering the code from email.
  Future<void> _confirmCode() async {
    final code = _verificationCodeController.text.trim();
    final email = _emailController.text.trim(); // same as username

    if (code.isEmpty) {
      setState(() => _errorMessage = '認証コードを入力してください。');
      return;
    }

    setState(() => _isRegistering = true);

    try {
      final isConfirmed = await CognitoService.instance.confirmSignUp(
        username: email,
        confirmationCode: code,
      );
      if (isConfirmed) {
        // success => show final success screen
        setState(() {
          _isSuccess = true;
          _awaitingConfirmationCode = false;
        });
      } else {
        setState(() => _errorMessage = '認証コードが正しくありません。');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isRegistering = false);
    }
  }

  /// For the Step 3 progress bar (2/3 to 1.0)
  Widget _buildProgressBar() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.66, end: 1.0),
      duration: const Duration(seconds: 1),
      builder: (context, value, child) {
        return LinearProgressIndicator(
          value: value,
          minHeight: 6,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('マスターアカウント作成'),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeIn,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              width: double.infinity,
              height: double.infinity,
              // Background image + gradient overlay
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage('assets/images/hero_image.png'),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primaryContainer.withValues(alpha: 0.2),
                    colorScheme.primaryContainer.withValues(alpha: 0.4),
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                const Text(
                                  'ステップ 3: マスターアカウント作成',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildProgressBar(),
                                const SizedBox(height: 24),

                                // Show companyId (read-only)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '会社ID: ${widget.companyId}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),

                                AnimatedCrossFade(
                                  duration: const Duration(milliseconds: 500),
                                  crossFadeState:
                                      (!_isRegistering && !_isSuccess)
                                          ? CrossFadeState.showFirst
                                          : (!_isSuccess
                                              ? CrossFadeState.showSecond
                                              : CrossFadeState.showFirst),
                                  firstChild: _buildFormOrConfirmation(),
                                  secondChild: _buildSpinner(),
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

  /// Depending on state:
  ///  - Show final success if `_isSuccess`
  ///  - Show code confirm if `_awaitingConfirmationCode`
  ///  - Otherwise show sign-up form
  Widget _buildFormOrConfirmation() {
    if (_isSuccess) {
      // success
      return Column(
        children: [
          const Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
          const SizedBox(height: 16),
          const Text(
            'マスターアカウントが登録されました！',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
            icon: const Icon(Icons.login, color: Colors.white),
            label: const Text('ログイン画面へ'),
          ),
        ],
      );
    } else if (_awaitingConfirmationCode) {
      // Show the code confirm UI
      return Column(
        children: [
          const Text(
            '入力したメールアドレスに認証コードを送信しました。\n受信したコードを入力してください。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _verificationCodeController,
            decoration: const InputDecoration(
              labelText: '認証コード',
              hintText: '123456',
            ),
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
            onPressed: _confirmCode,
            icon: const Icon(Icons.verified, color: Colors.white),
            label: const Text('コードを確認'),
          ),
        ],
      );
    } else {
      // The sign-up form (email + pw + confirm pw)
      return Column(
        children: [
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'メールアドレス (ログインID)',
              hintText: 'example@mail.com',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pwController,
            decoration: const InputDecoration(
              labelText: 'パスワード',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pwConfirmController,
            decoration: const InputDecoration(
              labelText: 'パスワード (確認)',
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
            onPressed: _signUpMasterUser,
            icon: const Icon(
              Icons.person_add,
              color: Colors.white,
              size: 20,
            ),
            label: const Text('ユーザーを登録'),
          ),
        ],
      );
    }
  }

  Widget _buildSpinner() {
    return Column(
      children: const [
        SizedBox(height: 8),
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text(
          '作成中...\nしばらくお待ちください',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      ],
    );
  }
}
