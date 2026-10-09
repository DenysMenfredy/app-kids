import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_button.dart';
import '../../../core/widgets/lele_card.dart';
import '../application/child_provider.dart';
import '../domain/child_record.dart';

/// Distinguishes an empty family from a pending or failed profile read.
class ChildProfileStatusCard extends StatelessWidget {
  const ChildProfileStatusCard({super.key, required this.state});

  final AsyncValue<ChildRecord?> state;

  @override
  Widget build(BuildContext context) {
    final loading = state.isLoading;
    final failed = state.hasError;
    return LeleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            const CircularProgressIndicator()
          else
            Icon(
              failed ? Icons.cloud_off_outlined : Icons.person_add_alt_1,
              size: 40,
              color: AppColors.orange,
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            loading
                ? 'Carregando perfis...'
                : failed
                ? 'Não foi possível carregar os perfis.'
                : 'Nenhum perfil cadastrado ainda.',
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            loading
                ? 'Aguarde enquanto buscamos os perfis da sua conta.'
                : failed
                ? 'Verifique sua conexão e tente novamente.'
                : 'Adicione uma criança para começar a jornada de aprendizado.',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Child-only routes wait for an actual profile before building their content.
/// This is a display guard; the backend remains responsible for authorization.
class ChildProfileGate extends ConsumerWidget {
  const ChildProfileGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(selectedChildStateProvider);
    if (!state.isLoading && !state.hasError && state.value != null) {
      return child;
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ChildProfileStatusCard(state: state),
              const SizedBox(height: AppSpacing.lg),
              if (!state.isLoading)
                LeleButton(
                  label: state.hasError
                      ? 'Tentar novamente'
                      : 'Adicionar criança',
                  onPressed: () {
                    if (state.hasError) {
                      ref.invalidate(childrenForParentProvider);
                    } else {
                      context.goNamed(
                        AppRoutes.profileSetup,
                        queryParameters: const {'new': 'true'},
                      );
                    }
                  },
                ),
              TextButton(
                onPressed: () => context.goNamed(AppRoutes.dashboard),
                child: const Text('Voltar ao painel dos pais'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
