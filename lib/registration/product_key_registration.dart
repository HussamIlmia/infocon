import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String _apiBaseUrl =
    'https://9v60ngmpp4.execute-api.ap-northeast-3.amazonaws.com/TESTING';

/// --------------------------------------------------------------------------
/// STEP 1: Registration Key Screen
/// --------------------------------------------------------------------------
class RegistrationKeyScreen extends StatefulWidget {
  const RegistrationKeyScreen({super.key});

  @override
  State<RegistrationKeyScreen> createState() => _RegistrationKeyScreenState();
}

class _RegistrationKeyScreenState extends State<RegistrationKeyScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  String? _errorText;

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

  /// Validates the code via your AWS API. If valid -> navigate, else show error.
  Future<void> _validateRegistrationKey(String code) async {
    // If empty, show an error
    if (code.isEmpty) {
      setState(() {
        _errorText = '登録キーを入力してください。';
      });
      return;
    }

    try {
      final uri = Uri.parse('$_apiBaseUrl/validateKey?key=$code');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        if (body['valid'] == true) {
          // If valid, navigate immediately
          Navigator.pushNamed(
            context,
            '/companyRegistration',
            arguments: code.trim(),
          );
        } else {
          setState(() {
            _errorText = body['message'] ?? '登録キーが正しくありません。';
          });
        }
      } else {
        setState(() {
          _errorText = 'サーバーエラー。ステータスコード: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorText = 'ネットワークエラー: $e';
      });
    }
  }

  void _onConfirmPressed() {
    _validateRegistrationKey(_codeController.text.trim());
  }

  /// Step Progress Bar with animation from 0 to 0.33
  Widget _buildProgressBar() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1 / 3),
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
        title: const Text('よろずAI'),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeIn,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              width: double.infinity,
              height: double.infinity,
              // Background image with gradient overlay
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 24,
                      ),
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
                                // STEP LABEL
                                const Text(
                                  '登録キーを入力',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // PROGRESS BAR
                                _buildProgressBar(),
                                const SizedBox(height: 24),

                                // TextField for the registration key
                                TextField(
                                  controller: _codeController,
                                  onSubmitted: (value) =>
                                      _validateRegistrationKey(value.trim()),
                                  decoration: InputDecoration(
                                    labelText: '登録キー',
                                    hintText: 'A12345789',
                                    errorText: _errorText,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                // Error text
                                if (_errorText != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _errorText!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ],
                                const SizedBox(height: 24),

                                // Confirm Button
                                ElevatedButton.icon(
                                  onPressed: _onConfirmPressed,
                                  icon: const Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  label: const Text('確認'),
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
