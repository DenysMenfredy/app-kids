import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../books/presentation/book_cover_style.dart';
import '../../../books/presentation/book_illustration.dart';
import '../../domain/story.dart';

class StoryPageCard extends StatelessWidget {
  const StoryPageCard({super.key, required this.page});
  final StoryPage page;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        height: 180,
        child: BookIllustration(
          scene: page.illustration,
          cover: defaultBookCover,
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      Text(
        page.text,
        style: AppTextStyles.subheading,
        textAlign: TextAlign.center,
      ),
    ],
  );
}

@Preview(name: 'Página de história', group: 'Lições', size: Size(340, 480))
Widget storyPagePreview() => const MaterialApp(
  home: Scaffold(
    body: Padding(
      padding: EdgeInsets.all(24),
      child: StoryPageCard(
        page: StoryPage(
          id: 'page_1',
          text: 'A lua apareceu no céu. O sapo saiu do lago.',
          illustration: 'moon',
        ),
      ),
    ),
  ),
);
