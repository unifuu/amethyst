import 'dart:io';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

void main() => runApp(const AmethystApp());

class AmethystApp extends StatelessWidget {
  const AmethystApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Amethyst',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff7256a8)),
      useMaterial3: true,
    ),
    home: const LibraryPage(),
  );
}

class MediaNote {
  MediaNote({required this.file, required this.kind, required this.fields});
  final File file;
  final String kind;
  final Map<String, String> fields;
  String get title {
    final value = fields['title']?.replaceAll('"', '').trim();
    return value == null || value.isEmpty
        ? file.uri.pathSegments.last.replaceFirst('.md', '')
        : value;
  }

  String get status => _cleanLink(fields['status'] ?? '');
  String get statusOption {
    if (status.contains('Off')) {
      return 'Off';
    }
    if (status.contains('Fin')) {
      return 'Fin';
    }
    return 'On';
  }

  int get statusRank {
    if (status.isEmpty) {
      return 3;
    }
    return switch (statusOption) {
      'On' => 0,
      'Off' => 1,
      'Fin' => 2,
      _ => 3,
    };
  }

  int? get progress => int.tryParse(fields['progress'] ?? '');
  int? get episodes => int.tryParse(fields['episodes'] ?? '');
  String get cover => fields['cover'] ?? '';
  String get subtitle {
    final parts = <String>[kind];
    if (progress != null && episodes != null) {
      parts.add('${progress!}/${episodes!}');
    }
    if ((fields['rating'] ?? '').isNotEmpty) parts.add('★ ${fields['rating']}');
    return parts.join(' · ');
  }
}

String _cleanLink(String raw) =>
    raw.replaceAll(RegExp(r'[\[\]]'), '').replaceAll('"', '').trim();

class NoteRepository {
  static Future<List<MediaNote>> load(String rootPath) async {
    final root = Directory(rootPath);
    final result = <MediaNote>[];
    await for (final collection in root.list(followLinks: false)) {
      if (collection is! Directory) {
        continue;
      }
      final name = collection.uri.pathSegments
          .where((segment) => segment.isNotEmpty)
          .last
          .toLowerCase();
      final kind = name.contains('anime')
          ? 'Anime'
          : name.contains('game')
          ? 'Game'
          : null;
      if (kind == null) {
        continue;
      }
      await for (final entity in collection.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File || !entity.path.endsWith('.md')) {
          continue;
        }
        final fields = _frontmatter(await entity.readAsString());
        if (fields.isNotEmpty) {
          result.add(MediaNote(file: entity, kind: kind, fields: fields));
        }
      }
    }
    result.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return result;
  }

  static Map<String, String> _frontmatter(String content) {
    final match = RegExp(
      r'^---\s*\n([\s\S]*?)\n---',
      multiLine: true,
    ).firstMatch(content);
    if (match == null) return {};
    final result = <String, String>{};
    String? activeKey;
    for (final line in match.group(1)!.split('\n')) {
      final property = RegExp(r'^([A-Za-z_]+):\s*(.*)$').firstMatch(line);
      if (property != null) {
        activeKey = property.group(1)!;
        result[activeKey] = property.group(2)!.trim();
      } else if (activeKey != null && line.trimLeft().startsWith('- ')) {
        result[activeKey] =
            '${result[activeKey]} ${line.trimLeft().substring(2)}'.trim();
      }
    }
    return result;
  }

  static Future<void> update(
    MediaNote note,
    Map<String, String> updates,
  ) async {
    var content = await note.file.readAsString();
    for (final entry in updates.entries) {
      final expression = RegExp(
        '^${RegExp.escape(entry.key)}:.*'
        r'$',
        multiLine: true,
      );
      final replacement = '${entry.key}: ${entry.value}';
      content = expression.hasMatch(content)
          ? content.replaceFirst(expression, replacement)
          : content.replaceFirst('---', '---\n$replacement');
      note.fields[entry.key] = entry.value;
    }
    final progress = int.tryParse(updates['progress'] ?? '');
    if (progress != null) {
      content = _syncEpisodeChecklist(content, progress);
    }
    await note.file.writeAsString(content);
  }

  static String _syncEpisodeChecklist(String content, int progress) {
    final heading = RegExp(
      r'^##\s+Episodes\s*$',
      multiLine: true,
    ).firstMatch(content);
    if (heading == null) return content;
    final bodyStart = heading.end;
    final remainder = content.substring(bodyStart);
    final nextHeading = RegExp(r'\n#{1,2}\s+\S').firstMatch(remainder);
    final bodyEnd = bodyStart + (nextHeading?.start ?? remainder.length);
    final body = content.substring(bodyStart, bodyEnd);
    final completedThrough = progress < 0 ? 0 : progress;
    final updated = body.replaceAllMapped(
      RegExp(r'^(\s*-\s*\[)[ xX](\]\s*)(\d+)(\.\s*.*)$', multiLine: true),
      (match) =>
          '${match.group(1)}${int.parse(match.group(3)!) <= completedThrough ? 'x' : ' '}${match.group(2)}${match.group(3)}${match.group(4)}',
    );
    return updated == body
        ? content
        : '${content.substring(0, bodyStart)}$updated${content.substring(bodyEnd)}';
  }
}

class AppConfig {
  static File get _file => File('${Directory.current.path}/config.json');

  static Future<Map<String, dynamic>> _read() async {
    if (!await _file.exists()) {
      return {};
    }
    try {
      final data = jsonDecode(await _file.readAsString());
      return data is Map<String, dynamic> ? data : {};
    } on FormatException {
      return {};
    }
  }

  static Future<void> _write(Map<String, dynamic> data) =>
      _file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));

  static Future<String?> loadNotesRootPath() async {
    final path = (await _read())['notesRootPath'];
    return path is String && await Directory(path).exists() ? path : null;
  }

  static Future<void> saveNotesRootPath(String path) async {
    final data = await _read();
    data['notesRootPath'] = path;
    await _write(data);
  }

  static Future<String?> loadOllamaModel() async {
    final model = (await _read())['ollamaModel'];
    return model is String && model.isNotEmpty ? model : null;
  }

  static Future<void> saveOllamaModel(String model) async {
    final data = await _read();
    data['ollamaModel'] = model;
    await _write(data);
  }
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  List<MediaNote> _notes = [];
  bool _loading = false;
  String _query = '';
  String _filter = 'All';
  String _sortBy = 'Title';

  @override
  void initState() {
    super.initState();
    _loadConfiguredFolder();
  }

  Future<void> _loadConfiguredFolder() async {
    final path = await AppConfig.loadNotesRootPath();
    if (path != null) {
      await _loadNotes(path);
    }
  }

  Future<void> _chooseFolder() async {
    final path = await getDirectoryPath(confirmButtonText: 'Open notes folder');
    if (path == null) {
      return;
    }
    await AppConfig.saveNotesRootPath(path);
    await _loadNotes(path);
  }

  Future<void> _loadNotes(String path) async {
    setState(() => _loading = true);
    try {
      final notes = await NoteRepository.load(path);
      if (mounted) {
        setState(() => _notes = notes);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not read notes: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<MediaNote> get _visible {
    final visible = _notes
        .where(
          (note) =>
              (_filter == 'All' || note.kind == _filter) &&
              note.title.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    if (_sortBy == 'Status') {
      visible.sort((a, b) {
        final rank = a.statusRank.compareTo(b.statusRank);
        return rank != 0
            ? rank
            : a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    }
    return visible;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Amethyst'),
      actions: [
        IconButton(
          onPressed: _notes.isEmpty
              ? null
              : () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LocalProgressChatPage(notes: _notes),
                  ),
                ),
          icon: const Icon(Icons.auto_awesome),
          tooltip: 'Update progress with local AI',
        ),
        PopupMenuButton<String>(
          tooltip: 'Sort notes',
          onSelected: (value) => setState(() => _sortBy = value),
          itemBuilder: (context) => [
            CheckedPopupMenuItem(
              value: 'Title',
              checked: _sortBy == 'Title',
              child: const Text('Sort by title'),
            ),
            CheckedPopupMenuItem(
              value: 'Status',
              checked: _sortBy == 'Status',
              child: const Text('Sort by status'),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.sort),
                const SizedBox(width: 4),
                Text('Sort: $_sortBy'),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: _chooseFolder,
          icon: const Icon(Icons.folder_open),
          tooltip: 'Choose notes folder',
        ),
      ],
    ),
    body: _notes.isEmpty && !_loading
        ? Center(
            child: FilledButton.icon(
              onPressed: _chooseFolder,
              icon: const Icon(Icons.folder_open),
              label: const Text('Choose your notes folder'),
            ),
          )
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: SearchBar(
                        hintText: 'Search titles',
                        leading: const Icon(Icons.search),
                        onChanged: (value) => setState(() => _query = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'All', label: Text('All')),
                        ButtonSegment(value: 'Game', label: Text('Games')),
                        ButtonSegment(value: 'Anime', label: Text('Anime')),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (value) =>
                          setState(() => _filter = value.first),
                    ),
                  ],
                ),
              ),
              if (_loading) const LinearProgressIndicator(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: (constraints.maxWidth / 270)
                          .floor()
                          .clamp(1, 5),
                      mainAxisExtent: 168,
                    ),
                    itemCount: _visible.length,
                    itemBuilder: (_, index) => NoteCard(
                      note: _visible[index],
                      onChanged: () => setState(() {}),
                    ),
                  ),
                ),
              ),
            ],
          ),
  );
}

class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.note, required this.onChanged});
  final MediaNote note;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        await showDialog<void>(
          context: context,
          builder: (_) => EditNoteDialog(note: note),
        );
        onChanged();
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: note.cover.isEmpty
                  ? const SizedBox(
                      width: 94,
                      height: 132,
                      child: ColoredBox(color: Color(0xffded7ec)),
                    )
                  : Image.network(
                      note.cover,
                      width: 94,
                      height: 132,
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stackTrace) => const SizedBox(
                        width: 94,
                        height: 132,
                        child: ColoredBox(color: Color(0xffded7ec)),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    note.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(note.subtitle),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(
                      note.status.isEmpty ? 'Untracked' : note.status,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class EditNoteDialog extends StatefulWidget {
  const EditNoteDialog({super.key, required this.note});
  final MediaNote note;
  @override
  State<EditNoteDialog> createState() => _EditNoteDialogState();
}

class _EditNoteDialogState extends State<EditNoteDialog> {
  late final TextEditingController _progress = TextEditingController(
    text: widget.note.progress?.toString() ?? '',
  );
  late String _status = widget.note.statusOption;
  bool _saving = false;
  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.note.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: const ['On', 'Off', 'Fin']
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: (value) => setState(() => _status = value!),
        ),
        if (widget.note.kind == 'Anime')
          TextField(
            controller: _progress,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText:
                  'Progress${widget.note.episodes == null ? '' : ' of ${widget.note.episodes}'}',
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving
            ? null
            : () async {
                setState(() => _saving = true);
                final updates = <String, String>{
                  'status':
                      '[[${_status == 'On'
                          ? '🟢'
                          : _status == 'Off'
                          ? '🟡'
                          : '🟣'} $_status]]',
                };
                if (widget.note.kind == 'Anime') {
                  updates['progress'] = _progress.text.trim();
                }
                if (_status == 'Fin') {
                  updates['finished'] = DateTime.now()
                      .toIso8601String()
                      .substring(0, 10);
                }
                await NoteRepository.update(widget.note, updates);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
        child: const Text('Save'),
      ),
    ],
  );
}

class ProgressIntent {
  const ProgressIntent({required this.title, required this.episode});
  final String title;
  final int episode;

  factory ProgressIntent.fromJson(Map<String, dynamic> data) {
    final title = data['title'];
    final episode = data['episode'];
    if (title is! String ||
        title.trim().isEmpty ||
        episode is! int ||
        episode < 1) {
      throw const FormatException(
        'The local model did not return a title and positive episode.',
      );
    }
    return ProgressIntent(title: title.trim(), episode: episode);
  }
}

class LocalOllamaClient {
  LocalOllamaClient({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();
  final HttpClient _httpClient;
  static final Uri _tagsUri = Uri.parse('http://127.0.0.1:11434/api/tags');
  static final Uri _chatUri = Uri.parse('http://127.0.0.1:11434/api/chat');

  Future<List<String>> listQwenModels() async {
    final request = await _httpClient
        .getUrl(_tagsUri)
        .timeout(const Duration(seconds: 3));
    final response = await request.close().timeout(const Duration(seconds: 3));
    final payload = jsonDecode(await utf8.decodeStream(response));
    if (response.statusCode != 200 || payload is! Map<String, dynamic>) {
      throw const HttpException('Ollama did not return its model list.');
    }
    final models = payload['models'];
    if (models is! List) return [];
    return models
        .whereType<Map>()
        .map((model) => model['name'])
        .whereType<String>()
        .where((name) => name.toLowerCase().contains('qwen'))
        .toList();
  }

  Future<ProgressIntent> parseProgress({
    required String model,
    required String message,
  }) async {
    final request = await _httpClient
        .postUrl(_chatUri)
        .timeout(const Duration(seconds: 3));
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode({
        'model': model,
        'stream': false,
        'format': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string'},
            'episode': {'type': 'integer', 'minimum': 1},
          },
          'required': ['title', 'episode'],
        },
        'messages': [
          {
            'role': 'system',
            'content': 'Extract a media title and watched episode number from the user message. Return JSON only. Support any language. Do not infer a missing title or episode.',
          },
          {'role': 'user', 'content': message},
        ],
        'options': {'temperature': 0},
      }),
    );
    final response = await request.close().timeout(const Duration(seconds: 60));
    final payload = jsonDecode(await utf8.decodeStream(response));
    if (response.statusCode != 200 || payload is! Map<String, dynamic>) {
      throw const HttpException('Ollama could not process the message.');
    }
    final content = (payload['message'] as Map?)?['content'];
    if (content is! String) {
      throw const FormatException(
        'Ollama did not return a structured response.',
      );
    }
    final intent = jsonDecode(content);
    if (intent is! Map<String, dynamic>) {
      throw const FormatException('Ollama returned invalid JSON.');
    }
    return ProgressIntent.fromJson(intent);
  }
}

class ProgressMatcher {
  static List<MediaNote> find(List<MediaNote> notes, String title) {
    final query = _normalize(title);
    if (query.isEmpty) return [];
    return notes.where((note) {
      final candidate = _normalize(note.title);
      return candidate == query ||
          candidate.contains(query) ||
          query.contains(candidate);
    }).toList();
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'''[\s\-_:;,.!?"'’“”「」『』]'''), '');

  static MediaNote? resolveDisambiguation(
    List<MediaNote> candidates,
    String reply,
  ) {
    final normalized = _normalize(reply);
    final direct = candidates
        .where((note) => _normalize(note.title) == normalized)
        .toList();
    if (direct.length == 1) return direct.single;
    final mentioned = candidates
        .where((note) => normalized.contains(_normalize(note.title)))
        .toList();
    if (mentioned.length == 1) return mentioned.single;
    final season = RegExp(r'season(\d+)').firstMatch(normalized)?.group(1);
    if (season != null && normalized.contains('not')) {
      final remaining = candidates
          .where((note) => !_normalize(note.title).contains('season$season'))
          .toList();
      return remaining.length == 1 ? remaining.single : null;
    }
    if (normalized.contains('first') || normalized.contains('1st')) {
      return candidates.isEmpty ? null : candidates.first;
    }
    if (normalized.contains('second') || normalized.contains('2nd')) {
      return candidates.length < 2 ? null : candidates[1];
    }
    return null;
  }
}

class LocalProgressChatPage extends StatefulWidget {
  const LocalProgressChatPage({super.key, required this.notes});
  final List<MediaNote> notes;
  @override
  State<LocalProgressChatPage> createState() => _LocalProgressChatPageState();
}

class _ChatMessage {
  const _ChatMessage(this.text, {required this.isUser});
  final String text;
  final bool isUser;
}

class _LocalProgressChatPageState extends State<LocalProgressChatPage> {
  final _client = LocalOllamaClient();
  final _controller = TextEditingController();
  final _messages = <_ChatMessage>[
    const _ChatMessage(
      'Tell me a title and episode, for example: “I watched episode 5 of Example Series.”',
      isUser: false,
    ),
  ];
  List<String> _models = [];
  String? _model;
  String? _connectionError;
  bool _sending = false;
  List<MediaNote> _pendingMatches = [];
  int? _pendingEpisode;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    try {
      final models = await _client.listQwenModels();
      final saved = await AppConfig.loadOllamaModel();
      if (!mounted) return;
      setState(() {
        _models = models;
        _model =
            models.contains(saved) && saved!.toLowerCase().startsWith('qwen3:')
            ? saved
            : _preferredModel(models);
        _connectionError = models.isEmpty
            ? 'No local Qwen model was found. Install one with Ollama, then reopen this page.'
            : null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _connectionError = 'Ollama is not running at http://127.0.0.1:11434. Start Ollama, then reopen this page.',
        );
      }
    }
  }

  String? _preferredModel(List<String> models) {
    for (final model in models) {
      if (model.toLowerCase().startsWith('qwen3:')) return model;
    }
    return models.isEmpty ? null : models.first;
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _model == null || _sending) return;
    setState(() {
      _messages.add(_ChatMessage(text, isUser: true));
      _sending = true;
    });
    _controller.clear();
    try {
      final reply = await _replyTo(text);
      if (mounted) {
        setState(() => _messages.add(_ChatMessage(reply, isUser: false)));
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _messages.add(
            _ChatMessage('I could not update progress: $error', isUser: false),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<String> _replyTo(String text) async {
    if (_pendingMatches.isNotEmpty && _pendingEpisode != null) {
      final chosen = ProgressMatcher.resolveDisambiguation(
        _pendingMatches,
        text,
      );
      if (chosen != null) {
        final episode = _pendingEpisode!;
        _pendingMatches = [];
        _pendingEpisode = null;
        return _applyProgress(chosen, episode);
      }
      return 'Please choose one of these titles: ${_pendingMatches.map((note) => note.title).join(', ')}.';
    }
    final intent = await _client.parseProgress(model: _model!, message: text);
    final matches = ProgressMatcher.find(widget.notes, intent.title);
    if (matches.isEmpty) {
      return 'I could not find “${intent.title}”. Please use the title from your library.';
    }
    if (matches.length == 1) {
      return _applyProgress(matches.single, intent.episode);
    }
    _pendingMatches = matches;
    _pendingEpisode = intent.episode;
    return 'I found multiple matches for “${intent.title}”: ${matches.map((note) => note.title).join(', ')}. Reply with the exact title, “first”, “second”, or for example “not season 2”.';
  }

  Future<String> _applyProgress(MediaNote note, int episode) async {
    await NoteRepository.update(note, {'progress': '$episode'});
    return 'Updated ${note.title} to episode $episode.';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Local progress assistant'),
      actions: [
        if (_models.isNotEmpty)
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _model,
              items: _models
                  .map(
                    (model) =>
                        DropdownMenuItem(value: model, child: Text(model)),
                  )
                  .toList(),
              onChanged: (model) async {
                if (model == null) return;
                setState(() => _model = model);
                await AppConfig.saveOllamaModel(model);
              },
            ),
          ),
        const SizedBox(width: 16),
      ],
    ),
    body: Column(
      children: [
        if (_connectionError != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_connectionError!),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (_, index) {
              final message = _messages[index];
              return Align(
                alignment: message.isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Card(
                  color: message.isUser
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(message.text),
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_sending && _model != null,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'I watched episode 5 of Example Series',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _sending || _model == null ? null : _send,
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
