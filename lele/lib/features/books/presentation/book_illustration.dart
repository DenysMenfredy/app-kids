import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text_styles.dart';
import 'book_cover_style.dart';

const _scenes = <String, ({String symbol, String label})>{
  'frog': (symbol: '🐸', label: 'Um sapinho sorridente'),
  'moon': (symbol: '🌙', label: 'A Lua no céu'),
  'sun': (symbol: '☀️', label: 'Um dia de sol'),
  'pond': (symbol: '🐸', label: 'O sapo na lagoa'),
  'vowels': (symbol: 'A E\nI O U', label: 'As cinco vogais'),
  'party': (symbol: '🎉', label: 'Uma festa colorida'),
  'letters': (symbol: 'ABC', label: 'Letras para brincar'),
  'cat': (symbol: '🐱', label: 'Um gatinho'),
  'dog': (symbol: '🐶', label: 'Uma cachorrinha'),
  'train': (symbol: '🚂', label: 'O trem das palavras'),
  'flowers': (symbol: '🌻', label: 'Flores no jardim'),
  'forest': (symbol: '🌳', label: 'Uma árvore'),
  'butterfly': (symbol: '🦋', label: 'Uma borboleta'),
  'book': (symbol: '📖', label: 'Um livro aberto'),
  'family': (symbol: '🏡', label: 'A casa da família'),
};

/// App-rendered scenes load instantly and need no external media URLs.
class BookIllustration extends StatelessWidget {
  const BookIllustration({
    super.key,
    required this.scene,
    required this.cover,
    this.isCover = false,
  });
  final String scene;
  final BookCover cover;
  final bool isCover;

  @override
  Widget build(BuildContext context) {
    final art = _scenes[scene] ?? _scenes['book']!;
    return Semantics(
      image: true,
      label: art.label,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: cover.gradient,
            ),
            border: isCover
                ? Border(left: BorderSide(color: cover.spine, width: 9))
                : null,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest.shortestSide;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: -size * .22,
                    right: -size * .18,
                    child: _Bubble(size: size * .75),
                  ),
                  Positioned(
                    bottom: -size * .28,
                    left: -size * .12,
                    child: _Bubble(size: size * .9),
                  ),
                  Positioned(
                    top: 14,
                    left: 22,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 21,
                      color: Colors.white.withValues(alpha: .8),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: ExcludeSemantics(
                          child: Text(
                            art.symbol,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.baloo(
                              scene == 'vowels' || scene == 'letters'
                                  ? 42
                                  : 100,
                              color: Colors.white,
                              weight: FontWeight.w800,
                            ).copyWith(height: 1.2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (isCover)
                    Positioned(
                      bottom: 12,
                      right: 14,
                      child: Text(
                        'lelê',
                        style: AppTextStyles.baloo(16, color: Colors.white),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: .14),
    ),
  );
}
