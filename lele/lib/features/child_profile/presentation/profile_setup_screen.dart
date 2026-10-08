import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_button.dart';
import '../../../core/widgets/lele_text_field.dart';
import '../../session/application/child_provider.dart';
import '../../session/application/session_controller.dart';
import '../../session/domain/child_profile.dart';
import '../../session/presentation/child_avatar_style.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({
    super.key,
    this.createNew = false,
    this.editExisting = false,
  });

  final bool createNew;
  final bool editExisting;

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  late final TextEditingController _nameController;
  late int _age;
  late ChildAvatar _avatar;
  bool _saving = false;
  late final String? _createRequestId;

  @override
  void initState() {
    super.initState();
    final child = widget.createNew
        ? ChildProfile.defaultProfile
        : ref.read(childProvider);
    _nameController = TextEditingController(text: child.name);
    _age = child.age;
    _avatar = child.avatar;
    _createRequestId = widget.createNew
        ? DateTime.now().microsecondsSinceEpoch.toRadixString(36)
        : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_saving) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final name = _nameController.text.trim();
    setState(() => _saving = true);
    try {
      await ref
          .read(sessionProvider.notifier)
          .saveChildProfile(
            ChildProfile(
              name: name.isEmpty ? ChildProfile.defaultProfile.name : name,
              age: _age,
              avatar: _avatar,
            ),
            createNew: widget.createNew,
            requestId: _createRequestId,
          );
      if (mounted) {
        context.goNamed(
          widget.editExisting ? AppRoutes.dashboard : AppRoutes.assessmentIntro,
        );
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Child profile save failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Não foi possível salvar. Verifique sua conexão e tente novamente.',
            ),
            action: SnackBarAction(
              label: 'Tentar novamente',
              onPressed: _continue,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(26, 32, 26, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Quem vai aprender?',
                      style: AppTextStyles.screenTitle,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    LeleTextField(
                      hint: 'Nome da criança',
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text('Idade', style: AppTextStyles.sectionTitle),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      spacing: AppSpacing.md,
                      children: [
                        for (final age in const [3, 4, 5, 6, 7])
                          Expanded(child: _ageChip(age)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Escolha o amiguinho',
                      style: AppTextStyles.sectionTitle,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Wrap: the avatars need a second row on a 320px phone
                    // rather than running off the edge.
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: AppSpacing.lg,
                      runSpacing: AppSpacing.lg,
                      children: [
                        for (final avatar in ChildAvatar.values)
                          _avatarChip(avatar),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.sm,
                AppSpacing.xxl,
                AppSpacing.xxl,
              ),
              child: SizedBox(
                width: double.infinity,
                child: LeleButton(
                  label: _saving ? 'Salvando...' : 'Continuar',
                  enabled: !_saving,
                  onPressed: _continue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ageChip(int age) {
    final selected = _age == age;
    return GestureDetector(
      onTap: () => setState(() => _age = age),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.orange : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.field),
          border: Border.all(
            color: selected ? AppColors.orange : AppColors.border,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: selected ? AppColors.orangeDark : AppColors.border,
              offset: Offset(0, selected ? 4 : 3),
            ),
          ],
        ),
        child: Text(
          '$age',
          style: AppTextStyles.baloo(
            20,
            color: selected ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _avatarChip(ChildAvatar avatar) {
    final selected = _avatar == avatar;
    return GestureDetector(
      onTap: () => setState(() => _avatar = avatar),
      child: AnimatedScale(
        scale: selected ? 1.12 : 1,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: avatar.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppColors.textDark : Colors.transparent,
              width: 4,
            ),
          ),
          child: const _AvatarFace(),
        ),
      ),
    );
  }
}

class _AvatarFace extends StatelessWidget {
  const _AvatarFace();

  @override
  Widget build(BuildContext context) {
    Widget eye() => Container(
      width: 12,
      height: 12,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: AppColors.textDark,
          shape: BoxShape.circle,
        ),
      ),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: AppSpacing.sm,
          children: [eye(), eye()],
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: 16,
          height: 8,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: Colors.black.withValues(alpha: 0.35),
                width: 3,
              ),
              right: BorderSide(
                color: Colors.black.withValues(alpha: 0.35),
                width: 3,
              ),
              bottom: BorderSide(
                color: Colors.black.withValues(alpha: 0.35),
                width: 3,
              ),
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}
