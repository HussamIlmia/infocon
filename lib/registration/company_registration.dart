import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String _apiBaseUrl =
    'https://9v60ngmpp4.execute-api.ap-northeast-3.amazonaws.com/TESTING';

class CompanyRegistrationScreen extends StatefulWidget {
  final String registrationKey;
  const CompanyRegistrationScreen({super.key, required this.registrationKey});

  @override
  State<CompanyRegistrationScreen> createState() =>
      _CompanyRegistrationScreenState();
}

class _CompanyRegistrationScreenState extends State<CompanyRegistrationScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isRegistering = false;
  bool _isSuccess = false;
  String? _companyId;

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

  Future<void> _registerCompany() async {
    final name = _companyNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('会社名を入力してください。')),
      );
      return;
    }

    setState(() {
      _isRegistering = true;
    });

    try {
      // Build the request body
      final body = {
        "registrationKey": widget.registrationKey,
        "companyName": _companyNameController.text.trim(),
        "address": _addressController.text.trim(),
        "phone": _phoneController.text.trim(),
      };

      final uri = Uri.parse('$_apiBaseUrl/companies');
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data["companyId"] != null) {
          setState(() {
            _isSuccess = true;
            _companyId = data["companyId"];
          });
        } else {
          setState(() => _isSuccess = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data["message"] ?? "会社登録に失敗しました。"),
            ),
          );
        }
      } else {
        setState(() => _isSuccess = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('エラーが発生しました。ステータスコード: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSuccess = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ネットワークエラー: $e')),
      );
    } finally {
      setState(() => _isRegistering = false);
    }

    // If success, wait 2 seconds so user sees the ID
    if (_isSuccess && _companyId != null) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      Navigator.pushNamed(
        context,
        '/masterUser',
        arguments: {
          'companyId': _companyId!,
        },
      );
    }
  }

  /// Step Progress Bar: from 0.33 to 0.66
  Widget _buildProgressBar() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.33, end: 2 / 3),
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
              // Background image + gradient overlay for consistency
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
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '会社情報登録',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildProgressBar(),
                                const SizedBox(height: 24),

                                // Either show the form/success OR the spinner
                                AnimatedCrossFade(
                                  duration: const Duration(milliseconds: 500),
                                  crossFadeState: !_isRegistering
                                      ? CrossFadeState.showFirst
                                      : !_isSuccess
                                          ? CrossFadeState.showSecond
                                          : CrossFadeState.showFirst,
                                  firstChild: _buildFormOrSuccess(),
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

  Widget _buildFormOrSuccess() {
    if (_isSuccess && _companyId != null) {
      return Column(
        children: [
          const Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
          const SizedBox(height: 16),
          const Text(
            '会社登録が完了しました！',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '会社ID: $_companyId',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
        ],
      );
    } else {
      // Show form
      return Column(
        children: [
          TextField(
            controller: _companyNameController,
            decoration: const InputDecoration(
              labelText: '会社名 *',
              hintText: '株式会社サンプル',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: '住所',
              hintText: '東京都港区1-2-3',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: '電話番号',
              hintText: '03-1234-5678',
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _registerCompany,
            icon: const Icon(
              Icons.domain_add,
              color: Colors.white,
              size: 20,
            ),
            label: const Text('会社情報を登録'),
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
          '会社情報登録中...\nしばらくお待ちください',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      ],
    );
  }
}
