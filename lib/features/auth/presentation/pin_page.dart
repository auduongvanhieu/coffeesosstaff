import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/device_context.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_logo.dart';
import '../application/auth_controller.dart';

const _pinLength = 4;

/// Figma "01 Đăng nhập" / "M1 Đăng nhập": 4-digit PIN pad for a terminal that
/// is already bound to a store.
class PinPage extends ConsumerStatefulWidget {
  const PinPage({super.key});

  @override
  ConsumerState<PinPage> createState() => _PinPageState();
}

class _PinPageState extends ConsumerState<PinPage> {
  String _pin = '';
  String? _error;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _tap(String digit) {
    if (_pin.length >= _pinLength) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == _pinLength) _submit();
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    if (_pin.length < _pinLength) {
      setState(() => _error = 'Nhập đủ $_pinLength số');
      return;
    }
    final pin = _pin;
    await ref.read(authControllerProvider.notifier).pinLogin(pin);
    if (!mounted) return;
    final auth = ref.read(authControllerProvider);
    if (auth.hasError) {
      setState(() {
        _pin = '';
        _error = describeError(auth.error!);
      });
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final ch = event.character;
    if (ch != null && RegExp(r'^[0-9]$').hasMatch(ch)) {
      _tap(ch);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _submit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final device = ref.watch(deviceContextProvider);
    final auth = ref.watch(authControllerProvider);
    final loading = auth.isLoading;
    final text = Theme.of(context).textTheme;

    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: AuthCard(
        maxWidth: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandLogo(size: 60, url: device?.brandLogoUrl),
            const SizedBox(height: 16),
            Text(
              AppConfig.appName.replaceAll(' Staff', ''),
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${device?.displayName ?? ''} — nhập mã PIN',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pinLength, (i) {
                final filled = i < _pin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.symmetric(horizontal: 7),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? AppColors.primary : AppColors.beigeDark,
                  ),
                );
              }),
            ),
            SizedBox(
              height: 28,
              child: Center(
                child: _error == null
                    ? (loading
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null)
                    : Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
            _Keypad(
              onDigit: loading ? null : _tap,
              onBackspace: loading ? null : _backspace,
              onOk: loading ? null : _submit,
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                ref.read(authControllerProvider.notifier).resetError();
                context.go(Routes.login);
              },
              child: const Text(
                'Đăng nhập bằng tài khoản khác',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onOk,
  });

  final void Function(String)? onDigit;
  final VoidCallback? onBackspace;
  final VoidCallback? onOk;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, bool primary = false}) {
      return Padding(
        padding: const EdgeInsets.all(5),
        child: Material(
          color: primary ? AppColors.primary : AppColors.beige,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
              width: 76,
              height: 52,
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: primary || label.length > 1 ? 15 : 20,
                    fontWeight: FontWeight.w600,
                    color: primary ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in rows)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final d in r)
                key(d, onTap: onDigit == null ? null : () => onDigit!(d)),
            ],
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            key('Xoá', onTap: onBackspace),
            key('0', onTap: onDigit == null ? null : () => onDigit!('0')),
            key('OK', onTap: onOk, primary: true),
          ],
        ),
      ],
    );
  }
}
