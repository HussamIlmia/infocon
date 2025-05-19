import 'package:flutter/material.dart';
import 'cognito_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPwController = TextEditingController();

  bool _isLoading = false;
  bool _isCodeSent = false; // toggles step 1 -> step 2
  bool _isSuccess = false;  // if password reset is done
  String? _errorMessage;

  late final AnimationController _controller;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    // Fade-in animation
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
    _codeController.dispose();
    _newPwController.dispose();
    super.dispose();
  }

  /// Step 1: Reset password request -> Cognito sends code to email
  Future<void> _sendResetCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'メールアドレスを入力してください。');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await CognitoService.instance.resetPassword(email);
      // If success, go to step 2
      setState(() => _isCodeSent = true);
    } catch (e) {
      setState(() => _errorMessage = 'エラーが発生しました: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Step 2: Confirm reset with code + new password
  Future<void> _confirmNewPassword() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final newPw = _newPwController.text.trim();

    if (code.isEmpty || newPw.isEmpty) {
      setState(() => _errorMessage = '認証コードと新しいパスワードを入力してください。');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await CognitoService.instance.confirmResetPassword(email, code, newPw);
      // If success
      setState(() => _isSuccess = true);
    } catch (e) {
      setState(() => _errorMessage = 'パスワード再設定中にエラーが発生しました: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeIn,
        // LayoutBuilder to get the full screen constraints for background
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              width: double.infinity,
              height: double.infinity,
              // Background image + gradient
              decoration: BoxDecoration(
                image: const DecorationImage(
                  image: AssetImage('assets/images/hero_image.png'),
                  fit: BoxFit.cover,
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
              child: Stack(
                children: [
                  // 1) Main Scrollable Content
                  SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      // Center both horizontally and vertically
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          // crossAxisAlignment not strictly needed here since Center
                          // is wrapping the Column, but you can also set it if you wish
                          children: [
                            const SizedBox(height: 24),
                            // Step content (email, code, or success)
                            _buildContent(),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 2) Loading overlay
                  if (_isLoading)
                    Container(
                      width: double.infinity,
                      height: constraints.maxHeight,
                      color: Colors.black26,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Returns the correct widget for the current step
  Widget _buildContent() {
    if (_isSuccess) {
      return _buildSuccessStep();
    } else if (!_isCodeSent) {
      return _buildEmailStep();
    } else {
      return _buildCodeStep();
    }
  }

  /// Step 3: Success message
  Widget _buildSuccessStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          const Text(
            'パスワードの再設定が完了しました。',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context), // Return to login
            icon: const Icon(Icons.login, color: Colors.white),
            label: const Text('ログイン画面に戻る'),
          ),
        ],
      ),
    );
  }

  /// Step 1: Ask for email
  Widget _buildEmailStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'パスワードを再設定するには、\n'
                  'ご登録のメールアドレスを入力してください。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'メールアドレス',
                    hintText: 'example@mail.com',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _sendResetCode,
                  icon: const Icon(Icons.email, color: Colors.white),
                  label: const Text('リセットコードを送信'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Step 2: Ask for code + new password
  Widget _buildCodeStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'メールに記載された認証コードと\n'
                  '新しいパスワードを入力してください。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: '認証コード',
                    hintText: '例: 123456',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _newPwController,
                  decoration: const InputDecoration(
                    labelText: '新しいパスワード',
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
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _confirmNewPassword,
                  icon: const Icon(Icons.lock_reset, color: Colors.white),
                  label: const Text('パスワードを再設定'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
