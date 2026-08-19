import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_button.dart';

class _Slide {
  const _Slide(this.imageLabel, this.title, this.body);

  final String imageLabel;
  final String title;
  final String body;
}

const _slides = [
  _Slide(
    'Ilustração: criança lendo com o mascote Lelê',
    'Uma jornada diária de leitura',
    '15 minutos por dia, no ritmo do seu filho — da coordenação motora às '
        'primeiras histórias.',
  ),
  _Slide(
    'Ilustração: atividades de tocar, ligar e traçar',
    'Brincadeiras que ensinam',
    'Tocar, ligar, traçar e escutar. Atividades curtas e divertidas, feitas '
        'para mãozinhas.',
  ),
  _Slide(
    'Ilustração: família acompanhando o progresso',
    'Pais sempre por perto',
    'Acompanhe o progresso, sem ranking e sem distração. Seguro e pensado '
        'para o Brasil.',
  ),
];

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pageController = PageController();
  int _step = 0;

  bool get _isLast => _step == _slides.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      context.goNamed(AppRoutes.register);
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 16),
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _step = i),
                  itemBuilder: (context, i) => _SlideView(slide: _slides[i]),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 8,
                children: [
                  for (var i = 0; i < _slides.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: i == _step ? 26 : 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: i == _step
                            ? AppColors.orange
                            : AppColors.border,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: LeleButton(
                  label: _isLast ? 'Criar conta' : 'Próximo',
                  onPressed: _next,
                ),
              ),
              GestureDetector(
                onTap: () => context.goNamed(AppRoutes.login),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Já tenho conta',
                    style: AppTextStyles.nunito(
                      15,
                      weight: FontWeight.w700,
                      color: AppColors.textFaint,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 230,
          height: 190,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.selectedFill,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Text(
            slide.imageLabel,
            textAlign: TextAlign.center,
            style: AppTextStyles.nunito(
              12,
              color: AppColors.textFaint,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          slide.title,
          textAlign: TextAlign.center,
          style: AppTextStyles.baloo(27, height: 1.2),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 290),
          child: Text(
            slide.body,
            textAlign: TextAlign.center,
            style: AppTextStyles.nunito(
              16,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
