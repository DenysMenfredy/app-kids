import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';
import '../domain/auth_failure.dart';
import 'apple_sign_in_button.dart';

final appleAccountLinkedProvider = StreamProvider<bool>((ref) {
  if (!AppConfig.useFirebase) return Stream.value(false);
  final auth = ref.watch(firebaseAuthProvider);
  return auth.userChanges().map(
    (user) =>
        user?.providerData.any(
          (provider) => provider.providerId == 'apple.com',
        ) ??
        false,
  );
});

/// Lets a signed-in parent attach Apple to their existing Firebase UID.
class AppleAccountLinkButton extends ConsumerStatefulWidget {
  const AppleAccountLinkButton({super.key});

  @override
  ConsumerState<AppleAccountLinkButton> createState() =>
      _AppleAccountLinkButtonState();
}

class _AppleAccountLinkButtonState
    extends ConsumerState<AppleAccountLinkButton> {
  bool _busy = false;

  Future<void> _link() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await ref.read(authControllerProvider).linkAppleAccount();
      if (!mounted) return;
      switch (result) {
        case AppleAccountLinkOutcome.linked:
          _showMessage('Conta Apple conectada a esta conta do Lelê.');
          ref.invalidate(appleAccountLinkedProvider);
        case AppleAccountLinkOutcome.alreadyLinked:
          _showMessage('Esta conta já está conectada com Apple.');
          ref.invalidate(appleAccountLinkedProvider);
        case AppleAccountLinkOutcome.cancelled:
          break;
      }
    } on AuthFailure catch (failure) {
      if (mounted) _showMessage(failure.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.red : AppColors.teal,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.useFirebase || !AppleSignInButton.isSupported) {
      return const SizedBox.shrink();
    }
    final linked = ref.watch(appleAccountLinkedProvider);
    if (linked.isLoading || linked.hasError || linked.value == true) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _busy
                ? 'Conectando o Apple ID a esta conta...'
                : 'Vincule seu Apple ID a esta conta:',
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: AppleSignInButton(
              label: 'Continuar com Apple',
              onPressed: _busy ? null : _link,
            ),
          ),
        ],
      ),
    );
  }
}
