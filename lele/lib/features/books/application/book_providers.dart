import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../paywall/application/entitlement_provider.dart';
import '../../session/application/child_provider.dart';
import '../../session/application/session_controller.dart';
import '../data/book_repository.dart';
import '../domain/book.dart';

final bookReadingScopeProvider = Provider<ReadingScope?>((ref) {
  final childId = ref.watch(activeChildIdProvider);
  if (!AppConfig.useFirebase) return (uid: 'demo', childId: childId);
  final auth = ref.watch(firebaseAuthUserProvider);
  final children = ref.watch(remoteChildrenProvider);
  if (auth.isLoading ||
      auth.hasError ||
      children.isLoading ||
      children.hasError) {
    return null;
  }
  final uid = auth.value?.uid;
  if (uid == null ||
      !children.requireValue.any((child) => child.id == childId)) {
    return null;
  }
  return (uid: uid, childId: childId);
});

final bookCatalogProvider = StreamProvider.autoDispose<List<Book>>((ref) {
  ref.watch(sessionStorageScopeProvider);
  if (AppConfig.useFirebase) {
    final auth = ref.watch(firebaseAuthUserProvider);
    if (auth.isLoading) return const Stream.empty();
    if (auth.hasError) return Stream.error(auth.error!, auth.stackTrace!);
    if (auth.value == null) return Stream.value(const []);
  }
  return ref.watch(bookRepositoryProvider).watchCatalog();
});

final bookBookmarksProvider =
    StreamProvider.autoDispose<Map<String, BookBookmark>>((ref) {
      final scope = ref.watch(bookReadingScopeProvider);
      if (scope == null) return Stream.value(const {});
      return ref.watch(bookRepositoryProvider).watchBookmarks(scope);
    });

final bookShelfSubtitleProvider = Provider<String>((ref) {
  final catalog = ref.watch(bookCatalogProvider);
  final premium = ref.watch(premiumBooksActiveProvider);
  if (catalog.isLoading) return 'Carregando histórias...';
  if (catalog.hasError) return 'Toque para abrir a biblioteca';
  final books = catalog.value ?? const <Book>[];
  final available = books
      .where(
        (book) =>
            book.access == BookAccess.free ||
            (!premium.isLoading && !premium.hasError && premium.value == true),
      )
      .length;
  if (books.isEmpty) return 'Novas histórias em breve';
  return available == 1
      ? '1 história para ler'
      : '$available histórias para ler';
});
