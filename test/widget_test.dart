import 'dart:io';

import 'package:amethyst/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes decorated note statuses for the editor', () {
    final onNote = MediaNote(
      file: File('example.md'),
      kind: 'Anime',
      fields: {'status': '[[🟢 On]]'},
    );
    final offNote = MediaNote(
      file: File('example.md'),
      kind: 'Game',
      fields: {'status': '[[🟡 Off]]'},
    );

    expect(onNote.statusOption, 'On');
    expect(onNote.status, '🟢 On');
    expect(offNote.statusOption, 'Off');
  });

  test('loads only direct media collections', () async {
    final root = await Directory.systemTemp.createTemp('amethyst_test_');
    addTearDown(() => root.delete(recursive: true));
    final games = await Directory('${root.path}/Games').create();
    final templates = await Directory('${root.path}/Templates').create();
    await File('${games.path}/included.md').writeAsString('''
---
title: Included game
---
''');
    await File('${templates.path}/Game.md').writeAsString('''
---
type: template
---
''');

    final notes = await NoteRepository.load(root.path);

    expect(notes, hasLength(1));
    expect(notes.single.title, 'Included game');
    expect(notes.single.kind, 'Game');
  });

  test('syncs episode checkboxes when progress changes', () async {
    final root = await Directory.systemTemp.createTemp(
      'amethyst_episode_test_',
    );
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}/series.md');
    await file.writeAsString('''
---
title: Example Series
progress: 0
---

## Episodes

- [ ] 1. First episode
- [ ] 2. Second episode
- [ ] 3. Third episode

## Notes

- [ ] 1. This must remain unchanged
''');
    final note = MediaNote(
      file: file,
      kind: 'Anime',
      fields: {'title': 'Example Series', 'progress': '0'},
    );

    await NoteRepository.update(note, {'progress': '3'});

    expect(await file.readAsString(), contains('- [x] 1. First episode'));
    expect(await file.readAsString(), contains('- [x] 3. Third episode'));
    expect(
      await file.readAsString(),
      contains('- [ ] 1. This must remain unchanged'),
    );
  });

  test('parses a local model progress intent', () {
    final intent = ProgressIntent.fromJson({
      'title': 'Example Series',
      'episode': 5,
    });

    expect(intent.title, 'Example Series');
    expect(intent.episode, 5);
  });

  test('matches a chat title to a local note', () {
    final note = MediaNote(
      file: File('example-series.md'),
      kind: 'Anime',
      fields: {'title': 'Example Series Season 1'},
    );

    expect(ProgressMatcher.find([note], 'Example Series'), [note]);
  });

  test('resolves a season disambiguation reply', () {
    final first = MediaNote(
      file: File('series-alpha.md'),
      kind: 'Anime',
      fields: {'title': 'Series Alpha'},
    );
    final second = MediaNote(
      file: File('series-alpha-season-2.md'),
      kind: 'Anime',
      fields: {'title': 'Series Alpha Season 2'},
    );

    expect(
      ProgressMatcher.resolveDisambiguation([first, second], 'Not season 2.'),
      first,
    );
    expect(
      ProgressMatcher.resolveDisambiguation([first, second], 'Series Alpha'),
      first,
    );
    expect(
      ProgressMatcher.resolveDisambiguation([
        first,
        second,
      ], 'The “Series Alpha” one.'),
      first,
    );
  });

  testWidgets('shows the folder chooser entry point', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AmethystApp());

    expect(find.text('Choose your notes folder'), findsOneWidget);
  });
}
