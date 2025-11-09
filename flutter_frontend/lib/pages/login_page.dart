import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../widgets/frosted_glass_button.dart';
import '../widgets/frosted_glass_textfield.dart';
import '../themes/colors.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late TextEditingController _usernameCtl, _passwordCtl;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _usernameCtl = TextEditingController();
    _passwordCtl = TextEditingController();
  }

  Future<void> _login() async {
    if (_usernameCtl.text.isEmpty || _passwordCtl.text.isEmpty) {
      setState(() => _errorMsg = 'Please fill in all fields');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final res = await apiClient.post('/login', {
        'username': _usernameCtl.text,
        'password': _passwordCtl.text,
      });
      final token = res['token'];
      final storageService = getStorageService();
      await storageService.write(key: 'token', value: token);
      apiClient.token = token;
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomePage()),
        );
      }
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signup() async {
    if (_usernameCtl.text.isEmpty || _passwordCtl.text.isEmpty) {
      setState(() => _errorMsg = 'Please fill in all fields');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final res = await apiClient.post('/signup', {
        'username': _usernameCtl.text,
        'password': _passwordCtl.text,
      });
      final token = res['token'];
      final storageService = getStorageService();
      await storageService.write(key: 'token', value: token);
      apiClient.token = token;
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomePage()),
        );
      }
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.2),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Grocery AI',
                  style: TextStyle(
                    fontFamily: 'Boska',
                    fontSize: 60,
                    fontWeight: FontWeight.w700,
                    color: kPrimary,
                  ),
                ),
              ),
              SizedBox(height: 5),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'From Group Chat to Grocery Cart',
                  style: TextStyle(
                    fontFamily: 'Boska',
                    fontWeight: FontWeight.w400,
                    fontSize: 16,
                    color: kTextGray,
                  ),
                ),
              ),
              SizedBox(height: 60),
              FrostedGlassTextField(
                controller: _usernameCtl,
                placeholder: 'Username',
                enabled: !_isLoading,
              ),
              SizedBox(height: 16),
              FrostedGlassTextField(
                controller: _passwordCtl,
                placeholder: 'Password',
                obscureText: true,
                enabled: !_isLoading,
              ),
              SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Forgot password?',
                  style: TextStyle(
                    fontSize: 12,
                    color: kPrimary,
                    decoration: TextDecoration.underline,
                    fontFamily: 'Boska',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              SizedBox(height: 24),
              if (_errorMsg != null)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMsg!,
                    style: TextStyle(
                      fontSize: 12,
                      color: kErrorRed,
                      fontFamily: 'Boska',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              SizedBox(height: 24),
              FrostedGlassButton(
                label: _isLoading ? 'Logging In...' : 'Log In',
                onPressed: _isLoading ? null : _login,
                isPrimary: true,
              ),
              SizedBox(height: 12),
              FrostedGlassButton(
                label: _isLoading ? 'Creating...' : 'Create Account',
                onPressed: _isLoading ? null : _signup,
                isPrimary: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameCtl.dispose();
    _passwordCtl.dispose();
    super.dispose();
  }
}
