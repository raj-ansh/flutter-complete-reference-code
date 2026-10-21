import 'package:flutter/material.dart';

import 'list_view_model.dart';
import 'state_views.dart';

// #docregion listscreenbody
/// The body of every list screen: spinner, error with retry, an optional
/// search box, a banner for failed actions, an empty state, or the items.
class ListScreenBody<T> extends StatelessWidget {
  const ListScreenBody({
    super.key,
    required this.state,
    required this.onRetry,
    required this.itemBuilder,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyHint,
    this.onSearch,
    this.searchHint = 'Search',
    this.header,
  });

  final ListState<T> state;
  final VoidCallback onRetry;
  final Widget Function(BuildContext context, T item) itemBuilder;

  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyHint;

  /// When given, a search box is shown above the list.
  final ValueChanged<String>? onSearch;
  final String searchHint;

  /// Anything extra above the list (for example a month calendar).
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      ListLoading() => const Center(child: CircularProgressIndicator()),
      ListFailed(:final message) => ErrorState(
        message: message,
        onRetry: onRetry,
      ),
      ListLoaded<T>() && final loaded => Column(
        children: [
          if (onSearch != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SearchBar(
                hintText: searchHint,
                leading: const Icon(Icons.search),
                onChanged: onSearch,
              ),
            ),
          // Everything below the search box scrolls together, so a tall header
          // (a calendar) can never overflow a short screen.
          Expanded(
            child: CustomScrollView(
              slivers: [
                if (header != null) SliverToBoxAdapter(child: header),
                if (loaded.message != null)
                  SliverToBoxAdapter(
                    child: MaterialBanner(
                      content: Text(loaded.message!),
                      actions: const [SizedBox.shrink()],
                    ),
                  ),
                if (loaded.items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: loaded.isSearching
                        ? const EmptyState(
                            icon: Icons.search_off,
                            title: 'Nothing matches',
                            hint: 'Try a different word.',
                          )
                        : EmptyState(
                            icon: emptyIcon,
                            title: emptyTitle,
                            hint: emptyHint,
                          ),
                  )
                else ...[
                  SliverList.builder(
                    itemCount: loaded.items.length,
                    itemBuilder: (context, i) =>
                        itemBuilder(context, loaded.items[i]),
                  ),
                  // Room under the last row, so the floating button never
                  // hides its trailing controls.
                  const SliverToBoxAdapter(child: SizedBox(height: 88)),
                ],
              ],
            ),
          ),
        ],
      ),
    };
  }
}
// #enddocregion listscreenbody
