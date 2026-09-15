import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/layout/adaptive_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_button.dart';

class _Slide {
  const _Slide({
    required this.image,
    required this.semanticLabel,
    required this.title,
    required this.body,
  });

  final String image;

  /// Read aloud in place of the illustration by a screen reader.
  final String semanticLabel;
  final String title;
  final String body;
}

const _slides = [
  _Slide(
    image: 'assets/images/onboarding/mascot_reading.png',
    semanticLabel: 'O mascote Lelê lendo um livro, cercado de livros',
    title: 'Uma jornada diária de leitura',
    body:
        '15 minutos por dia, no ritmo do seu filho — da coordenação motora '
        'às primeiras histórias.',
  ),
  _Slide(
    image: 'assets/images/onboarding/letter_blocks.png',
    semanticLabel: 'Criança sorrindo entre blocos com as letras A, B e C',
    title: 'Brincadeiras que ensinam',
    body:
        'Tocar, ligar, traçar e escutar. Atividades curtas e divertidas, '
        'feitas para mãozinhas.',
  ),
  _Slide(
    image: 'assets/images/onboarding/reading_together.png',
    semanticLabel: 'Pai e filha lendo juntos no tablet',
    title: 'Pais sempre por perto',
    body:
        'Acompanhe o progresso, sem ranking e sem distração. Seguro e '
        'pensado para o Brasil.',
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decode all three up front. Without this each slide shows an empty gap
    // where the illustration belongs the first time it is swiped to, because
    // the decode only starts when the slide is built.
    for (final slide in _slides) {
      precacheImage(AssetImage(slide.image), context);
    }
  }

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
                        color: i == _step ? AppColors.orange : AppColors.border,
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
    // A phone in landscape has roughly 390px of height for art, a heading
    // and a paragraph; a tall phone has more than twice that. The slide
    // keeps its proportions instead of keeping its pixel sizes.
    final short = context.isShort;
    // Centred when the slide fits, scrolling when it does not, so the copy
    // is never clipped on a short screen.
    return AdaptivePage(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // The art carries its own transparent background, so it sits on
          // the cream page directly rather than inside a tinted card. A
          // computed height rather than Flexible, which cannot shrink a
          // fixed-size Image and cannot live inside a scroll view.
          SizedBox(
            height: (MediaQuery.sizeOf(context).height * 0.30).clamp(
              76.0,
              260.0,
            ),
            child: Image.asset(
              slide.image,
              fit: BoxFit.contain,
              semanticLabel: slide.semanticLabel,
            ),
          ),
          SizedBox(height: short ? 12 : 24),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: AppTextStyles.baloo(short ? 22 : 27, height: 1.2),
          ),
          SizedBox(height: short ? 6 : 10),
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
      ),
    );
  }
}
