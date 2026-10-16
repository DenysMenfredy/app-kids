import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/lele_button.dart';
import '../application/notification_controller.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsState();
}

class _NotificationSettingsState
    extends ConsumerState<NotificationSettingsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(notificationControllerProvider).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(notificationControllerProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final preferences = controller.preferences;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Avisos para os pais'),
            leading: IconButton(
              tooltip: 'Voltar ao painel',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.goNamed(AppRoutes.dashboard),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  size: 60,
                  color: AppColors.orange,
                ),
                const SizedBox(height: 16),
                Text(
                  'Uma ajudinha para manter o ritmo',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Receba lembretes e avisos no seu aparelho. Não mostramos nomes nem informações das crianças na notificação. Você escolhe se quer receber; aprender continua disponível sem os avisos.',
                ),
                const SizedBox(height: 16),
                if (!controller.supported)
                  const Text(
                    'A demonstração está disponível no app para Android e iOS.',
                  )
                else ...[
                  Text(
                    controller.permitted
                        ? 'Permissão do aparelho: concedida'
                        : 'Permissão do aparelho: não concedida',
                  ),
                  if (!controller.localDemo)
                    Text(
                      controller.registered
                          ? 'Envio remoto: conectado'
                          : 'Envio remoto: não conectado',
                    ),
                  const SizedBox(height: 12),
                  LeleButton(
                    label: controller.busy
                        ? 'Aguarde...'
                        : 'Ativar avisos neste aparelho',
                    enabled: !controller.busy,
                    onPressed: controller.enable,
                  ),
                  if (controller.enabled)
                    TextButton(
                      onPressed: controller.busy ? null : controller.disable,
                      child: const Text('Desativar avisos neste aparelho'),
                    ),
                ],
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Experimente agora',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Esta demonstração é local: aparece na central de notificações, com ícone e som do sistema. Não testa o envio remoto do Firebase.',
                        ),
                        if (controller.localDemo) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'O emulador Firebase não envia push FCM. Nenhuma credencial é necessária para esta demonstração.',
                          ),
                        ],
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          key: const Key('notification-demo'),
                          onPressed: controller.busy || !controller.supported
                              ? null
                              : controller.showDemo,
                          icon: const Icon(Icons.notifications_outlined),
                          label: const Text('Mostrar demonstração'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (controller.message != null) ...[
                  const SizedBox(height: 12),
                  Semantics(liveRegion: true, child: Text(controller.message!)),
                ],
                const SizedBox(height: 24),
                Text(
                  'O que receber',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Lembrete de prática'),
                  value: preferences.dailyReminder,
                  onChanged: controller.busy
                      ? null
                      : (value) => controller.save(
                          preferences.copyWith(dailyReminder: value),
                        ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Conquistas'),
                  value: preferences.achievement,
                  onChanged: controller.busy
                      ? null
                      : (value) => controller.save(
                          preferences.copyWith(achievement: value),
                        ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Resumo semanal'),
                  value: preferences.weeklyReport,
                  onChanged: controller.busy
                      ? null
                      : (value) => controller.save(
                          preferences.copyWith(weeklyReport: value),
                        ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Avisos de assinatura'),
                  value: preferences.subscription,
                  onChanged: controller.busy
                      ? null
                      : (value) => controller.save(
                          preferences.copyWith(subscription: value),
                        ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Horário do lembrete'),
                  subtitle: Text(preferences.preferredTime),
                  trailing: const Icon(Icons.schedule),
                  onTap: controller.busy
                      ? null
                      : () async {
                          final parts = preferences.preferredTime.split(':');
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: int.tryParse(parts.first) ?? 18,
                              minute: int.tryParse(parts.last) ?? 0,
                            ),
                          );
                          if (time != null) {
                            await controller.save(
                              preferences.copyWith(
                                preferredTime:
                                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                              ),
                            );
                          }
                        },
                ),
                DropdownButtonFormField<String>(
                  initialValue:
                      const [
                        'America/Belem',
                        'America/Sao_Paulo',
                        'America/Manaus',
                        'America/Rio_Branco',
                      ].contains(preferences.timezone)
                      ? preferences.timezone
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Fuso do lembrete',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'America/Belem',
                      child: Text('Belém (UTC−3)'),
                    ),
                    DropdownMenuItem(
                      value: 'America/Sao_Paulo',
                      child: Text('Brasília (UTC−3)'),
                    ),
                    DropdownMenuItem(
                      value: 'America/Manaus',
                      child: Text('Manaus (UTC−4)'),
                    ),
                    DropdownMenuItem(
                      value: 'America/Rio_Branco',
                      child: Text('Rio Branco (UTC−5)'),
                    ),
                  ],
                  onChanged: controller.busy
                      ? null
                      : (value) {
                          if (value != null) {
                            controller.save(
                              preferences.copyWith(timezone: value),
                            );
                          }
                        },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Marketing não é ativado por esta tela. Os envios automáticos dependem da configuração e publicação do serviço.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
