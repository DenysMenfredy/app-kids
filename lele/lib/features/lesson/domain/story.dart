import 'package:equatable/equatable.dart';

class StoryPage extends Equatable {
  const StoryPage({
    required this.id,
    required this.text,
    required this.illustration,
  });
  final String id;
  final String text;
  final String illustration;
  @override
  List<Object?> get props => [id, text, illustration];
}

class StoryQuestion extends Equatable {
  const StoryQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.answer,
  });
  final String id;
  final String prompt;
  final List<String> options;
  // Feedback only. The server scores independently against published content.
  final String answer;
  @override
  List<Object?> get props => [id, prompt, options, answer];
}

class StoryActivity extends Equatable {
  const StoryActivity({
    required this.id,
    required this.storyId,
    required this.title,
    required this.contentVersion,
    required this.pages,
    required this.questions,
  });
  final String id;
  final String storyId;
  final String title;
  final int contentVersion;
  final List<StoryPage> pages;
  final List<StoryQuestion> questions;
  @override
  List<Object?> get props => [
    id,
    storyId,
    title,
    contentVersion,
    pages,
    questions,
  ];
}
