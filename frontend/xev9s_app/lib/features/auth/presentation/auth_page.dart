import 'package:material_ui/material_ui.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    this.isRegister = false,
  });

  final bool isRegister;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isRegister ? 'Create Account' : 'Sign In'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isRegister ? 'Register Page (Placeholder)' : 'Sign In Page (Placeholder)'),
          ],
        ),
      ),
    );
  }
}
