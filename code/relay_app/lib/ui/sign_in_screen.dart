import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/result.dart';
import '../state/session_view_model.dart';

// #docregion signin
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.initialServer = 'http://10.0.2.2:3000'});

  /// 10.0.2.2 is how the Android emulator reaches the computer it runs on.
  final String initialServer;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late final _server = TextEditingController(text: widget.initialServer);
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _createAccount = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _server.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return; // a second tap while waiting must not send a second request
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await context.read<SessionViewModel>().signIn(
      serverUrl: _server.text,
      username: _username.text,
      password: _password.text,
      createAccount: _createAccount,
    );
    if (!mounted) return;
    // On success the router moves us away; only a failure stays on screen.
    if (result is Err<void>) {
      setState(() {
        _busy = false;
        _error = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // The state can already be SignedIn for a frame while the router moves us
    // away, so test the type instead of casting.
    final state = context.watch<SessionViewModel>().state;
    final notice = state is SignedOut ? state.notice : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Relay')),
      body: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (notice != null)
              Card(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(notice),
                ),
              ),
            TextField(
              controller: _server,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Server',
                helperText: 'For example http://10.0.2.2:3000',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _username,
              autofillHints: const [AutofillHints.username],
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              autofillHints: [
                _createAccount
                    ? AutofillHints.newPassword
                    : AutofillHints.password,
              ],
              obscureText: !_showPassword,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: _createAccount ? 'At least 10 characters' : null,
                suffixIcon: IconButton(
                  tooltip: _showPassword ? 'Hide password' : 'Show password',
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_createAccount ? 'Create account' : 'Sign in'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _createAccount = !_createAccount;
                      _error = null;
                    }),
              child: Text(
                _createAccount
                    ? 'I already have an account'
                    : 'Create a new account',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// #enddocregion signin
