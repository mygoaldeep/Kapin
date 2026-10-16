import 'package:flutter/material.dart';

import '../services/backend.dart';
import '../theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = Backend.instance.auth;
      if (_register) {
        await auth.register(_email.text.trim(), _password.text);
      } else {
        await auth.signIn(_email.text.trim(), _password.text);
      }
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final size = MediaQuery.sizeOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: scheme.primary,
      body: Container(
        decoration: BoxDecoration(gradient: brandGradient(scheme)),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: size.height - MediaQuery.paddingOf(context).top),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(28, keyboard ? 12 : 36, 28, keyboard ? 16 : 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(Icons.location_on_rounded,
                                color: Colors.white, size: 30),
                          ),
                          if (!keyboard) ...[
                            const SizedBox(height: 22),
                            Text('Kapin',
                                style: text.displaySmall?.copyWith(
                                    color: Colors.white, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            Text(
                              'Share your live location with the people you choose, for as long as you choose.',
                              style: text.bodyLarge
                                  ?.copyWith(color: Colors.white.withValues(alpha: 0.88)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Form sheet
                  Container(
                    constraints: BoxConstraints(minHeight: size.height * 0.55),
                    padding: EdgeInsets.fromLTRB(
                        24, 28, 24, 24 + MediaQuery.paddingOf(context).bottom),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(_register ? 'Create your account' : 'Welcome back',
                              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 18),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(value: false, label: Text('Sign in')),
                              ButtonSegment(value: true, label: Text('Register')),
                            ],
                            selected: {_register},
                            showSelectedIcon: false,
                            onSelectionChanged: (s) => setState(() {
                              _register = s.first;
                              _error = null;
                            }),
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                            validator: (v) =>
                                (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            autofillHints: [
                              _register ? AutofillHints.newPassword : AutofillHints.password
                            ],
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) =>
                                (v == null || v.length < 6) ? 'At least 6 characters' : null,
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            child: _error == null
                                ? const SizedBox(width: double.infinity)
                                : Padding(
                                    padding: const EdgeInsets.only(top: 14),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: scheme.errorContainer,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.error_outline,
                                              color: scheme.onErrorContainer),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(_error!,
                                                style:
                                                    TextStyle(color: scheme.onErrorContainer)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5),
                                  )
                                : Text(_register ? 'Create account' : 'Sign in'),
                          ),
                          if (Backend.instance.isDemo) ...[
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: scheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.science_outlined,
                                      size: 20, color: scheme.onTertiaryContainer),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Test mode: not connected to Firebase yet. Any email and a '
                                      '6+ character password will work; nothing is saved online.',
                                      style: TextStyle(
                                          fontSize: 13, color: scheme.onTertiaryContainer),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
