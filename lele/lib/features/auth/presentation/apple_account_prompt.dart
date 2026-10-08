import 'package:flutter/material.dart';

/// Gives a parent a chance to return to their existing UID before a newly
/// created Apple identity proceeds to child-profile onboarding (notably when
/// Hide My Email is selected). `true` continues; `false` returns to sign-in.
Future<bool?> showAppleAccountCreationPrompt(BuildContext context) =>
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Você já tem uma conta no Lelê?'),
        content: const Text(
          'Se você já usa e-mail ou Google, entre nessa conta primeiro e '
          'conecte o Apple ID para manter o perfil e o progresso juntos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Já tenho uma conta'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continuar com Apple'),
          ),
        ],
      ),
    );
