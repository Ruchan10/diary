import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/entry_repository.dart';
import '../navigation.dart';
import '../theme/moods.dart';
import '../widgets/entry_tile.dart';
import '../theme/theme.dart';
import '../widgets/inky.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  int? _mood;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final repo = context.watch<EntryRepository>();
    final query = _query.text.trim();
    final searching = query.isNotEmpty || _mood != null;
    final results = searching ? repo.search(query, mood: _mood) : const [];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _query,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          style: theme.textTheme.titleMedium,
          decoration: InputDecoration(
            hintText: 'Search your diary',
            border: InputBorder.none,
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    onPressed: () => setState(_query.clear),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Clear',
                  ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final m in moods)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text('${m.emoji}  ${m.label}'),
                      selected: _mood == m.value,
                      onSelected: (on) => setState(() => _mood = on ? m.value : null),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: !searching
          ? _Hint(
              icon: const Inky(size: 88, look: Offset(0.9, -0.3)),
              title: 'Inky can sniff out any memory',
              subtitle: repo.isEmpty
                  ? 'Once you’ve written a few pages, search them here.'
                  : 'Try a name, a place, a feeling… or pick a mood.',
            )
          : results.isEmpty
          ? const _Hint(
              icon: Inky(size: 88, face: InkyFace.sad),
              title: 'Inky looked under every page…',
              subtitle: 'Nothing matches. Try fewer words?',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: results.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '${results.length} ${results.length == 1 ? 'page' : 'pages'}',
                      style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  );
                }
                final e = results[i - 1];
                return EntryTile(
                  entry: e,
                  highlight: query,
                  onTap: () => AppNav.openCompose(context, e.day),
                );
              },
            ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.title, required this.subtitle});

  final Widget icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: handStyle(21, color: theme.colorScheme.onSurfaceVariant, weight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
