import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes/route_names.dart';
import '../../../core/widgets/error_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/magic/glassmorphic_card.dart';
import '../../../core/widgets/rounded_image.dart';
import '../../../ui/components/asset_icon.dart';
import '../data/book_providers.dart';
import '../../../core/utils/text_style_helpers.dart';
import '../../../ui/layouts/desktop_container.dart';

class ChildBooksScreen extends ConsumerWidget {
  final String childId;

  const ChildBooksScreen({
    super.key,
    required this.childId,
  });

  String _getStatusText(String status) {
    switch (status) {
      case 'draft':
        return 'Черновик';
      case 'editing':
        return 'Редактирование';
      case 'final':
        return 'Готово';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.orange;
      case 'editing':
        return Colors.blue;
      case 'final':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(childBooksProvider(childId));
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/logo/storyhero_bg_books_list.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Container(
              color: Colors.black.withOpacity(0.15),
            ),
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: const Text('Книги ребёнка'),
              ),
              body: booksAsync.when(
                data: (books) {
                  if (books.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AssetIcon(
                            assetPath: AppIcons.myBooks,
                            size: 80,
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Нет книг',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Создайте первую книгу для этого ребёнка',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    );
                  }

                  return SafeArea(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        final _ = ref.refresh(childBooksProvider(childId));
                        await Future.delayed(const Duration(milliseconds: 500));
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                        child: DesktopContainer(
                          maxWidth: 1100,
                          child: GridView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: screenWidth < 480 ? 1 : 2,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                            childAspectRatio: screenWidth < 480 ? 0.95 : 0.8,
                          ),
                            itemCount: books.length,
                            itemBuilder: (context, index) {
                              final book = books[index];
                              return Hero(
                                tag: 'book_${book.id}',
                                child: GlassmorphicCard(
                                  margin: EdgeInsets.zero,
                                  onTap: () {
                                    context.push(RouteNames.bookView.replaceAll(':id', book.id));
                                  },
                                  padding: EdgeInsets.zero,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(24),
                                        ),
                                        child: Stack(
                                          children: [
                                            _BookCoverImage(
                                              coverUrl: book.coverUrl,
                                              bookId: book.id,
                                            ),
                                            Positioned(
                                              top: 12,
                                              right: 12,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _getStatusColor(book.status).withOpacity(0.25),
                                                  borderRadius: BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: _getStatusColor(book.status),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Text(
                                                  _getStatusText(book.status),
                                                  style: TextStyle(
                                                    color: _getStatusColor(book.status),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(14.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                book.title,
                                                style: safeCopyWith(
                                                  Theme.of(context).textTheme.titleMedium,
                                                  fontSize: 18.0,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                '${book.createdAt.day}.${book.createdAt.month}.${book.createdAt.year}',
                                                style: safeCopyWith(
                                                  Theme.of(context).textTheme.bodySmall,
                                                  fontSize: 12.0,
                                                  color: safeCopyWith(
                                                    Theme.of(context).textTheme.bodyMedium,
                                                    fontSize: 14.0,
                                                  ).color?.withOpacity(0.7),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const LoadingWidget(),
                error: (error, stack) => ErrorDisplayWidget(
                  error: error,
                  onRetry: () => ref.refresh(childBooksProvider(childId)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookCoverImage extends ConsumerWidget {
  final String? coverUrl;
  final String bookId;

  const _BookCoverImage({
    required this.coverUrl,
    required this.bookId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (coverUrl != null && coverUrl!.isNotEmpty) {
      return RoundedImage(
        imageUrl: coverUrl,
        width: double.infinity,
        height: 180,
        radius: 0,
      );
    }

    final scenesAsync = ref.watch(bookScenesProvider(bookId));
    return scenesAsync.when(
      data: (scenes) {
        if (scenes.isEmpty) {
          return const RoundedImage(
            imageUrl: null,
            width: double.infinity,
            height: 180,
            radius: 0,
          );
        }
        final sortedScenes = [...scenes]..sort((a, b) => a.order.compareTo(b.order));
        final firstScene = sortedScenes.first;
        final imageUrl = firstScene.finalUrl ?? firstScene.draftUrl;
        return RoundedImage(
          imageUrl: imageUrl,
          width: double.infinity,
          height: 180,
          radius: 0,
        );
      },
      loading: () => const RoundedImage(
        imageUrl: null,
        width: double.infinity,
        height: 180,
        radius: 0,
      ),
      error: (_, __) => const RoundedImage(
        imageUrl: null,
        width: double.infinity,
        height: 180,
        radius: 0,
      ),
    );
  }
}
