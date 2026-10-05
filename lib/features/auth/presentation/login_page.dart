import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/credential_storage.dart';
import '../../../core/storage/device_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_logo.dart';
import '../application/auth_controller.dart';

/// Email + password sign-in. Used the first time a terminal is set up and as a
/// fallback from the PIN pad ("Đăng nhập bằng tài khoản khác").
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _remember = true;
  bool _hadSaved = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  /// Fills the form from the keychain so a shared terminal does not have to
  /// retype the account every time.
  Future<void> _loadSaved() async {
    final saved = await ref.read(credentialStorageProvider).read();
    if (saved == null || !mounted) return;
    setState(() {
      _email.text = saved.email;
      _password.text = saved.password;
      _hadSaved = true;
    });
  }

  Future<void> _forget() async {
    await ref.read(credentialStorageProvider).clear();
    if (!mounted) return;
    setState(() {
      _email.clear();
      _password.clear();
      _remember = false;
      _hadSaved = false;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Đã xoá đăng nhập đã lưu')));
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _email.text.trim();
    final password = _password.text;
    await ref.read(authControllerProvider.notifier).login(email, password);
    if (!mounted) return;
    // Only remember a login that actually worked.
    final signedIn = ref.read(authControllerProvider).value != null;
    if (!signedIn) return;
    final store = ref.read(credentialStorageProvider);
    await (_remember ? store.save(email, password) : store.clear());
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final device = ref.watch(deviceContextProvider);
    final isLoading = auth.isLoading;
    final error = auth.hasError ? describeError(auth.error!) : null;
    final text = Theme.of(context).textTheme;

    return AuthCard(
      maxWidth: 360,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: BrandLogo(
                size: 60,
                url: ref.watch(deviceContextProvider)?.brandLogoUrl,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppConfig.appName,
              textAlign: TextAlign.center,
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Đăng nhập để bắt đầu ca làm',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Email không hợp lệ' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Mật khẩu',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'Tối thiểu 6 ký tự' : null,
            ),
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _remember = !_remember),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Checkbox(
                      value: _remember,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) => setState(() => _remember = v ?? false),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Ghi nhớ đăng nhập trên máy này',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: isLoading ? null : _submit,
              child: isLoading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Đăng nhập'),
            ),
            if (device != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  ref.read(authControllerProvider.notifier).resetError();
                  context.go(Routes.pin);
                },
                child: const Text('Nhập mã PIN'),
              ),
            ],
            if (_hadSaved)
              TextButton(
                onPressed: _forget,
                child: const Text(
                  'Xoá đăng nhập đã lưu',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
