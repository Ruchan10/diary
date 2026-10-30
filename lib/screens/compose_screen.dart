import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/entry_repository.dart';
import '../services/app_lock.dart';
import '../services/celebrations.dart';
import '../services/settings.dart';
import '../theme/moods.dart';
import '../theme/theme.dart';
import '../utils/dates.dart';
import '../utils/prompts.dart';
import '../utils/stats.dart';
import '../widgets/inky.dart';
import '../widgets/mood_picker.dart';

enum _SaveStatus { idle, editing, saved, failed }

const _wordMilestones = [
  (10, 'Ooh, go on…'),
  (50, 'Juicy details! 😋'),
  (100, 'A whole story!'),
  (250, 'You’re on fire 🔥'),
  (500, 'Epic page! 📜'),
];

const _encouragements = [
  'I’m all ears 👂',
  'And then what happened?',
  'I won’t tell anyone. Promise.',
  'Typos are just ink splats 💦',
  'Take your time, I’m comfy here.',
];

/// The page for one day. Opens on launch for today with the keyboard up, and
/// from the calendar for any past day. Everything autosaves.
class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key, required this.day});

  final DateTime day;

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  // Resolved in initState: dispose() must not look anything up in the tree.
  late final EntryRepository _repo;
  late final AppLockController _lock;
  late final Celebrations _celebrations;
  late final TextEditingController _text;
  late final AppLifecycleListener _lifecycle;
  late final bool _focusOnOpen;
  late final bool _wasWrittenToday;
  late String _prompt;
  final _focus = FocusNode();
  final _inky = GlobalKey<InkyState>();
  final _random = Random();

  String _lastText = '';
  int? _mood;
  Timer? _debounce;
  bool _dirty = false;
  bool _deleted = false;
  bool _celebrated = false;
  _SaveStatus _status = _SaveStatus.idle;
  int _milestone = 0;
  String? _bubble;
  Timer? _bubbleTimer;

  bool get _isToday => isSameDay(widget.day, today());

  @override
  void initState() {
    super.initState();
    _repo = context.read<EntryRepository>();
    _lock = context.read<AppLockController>();
    _celebrations = context.read<Celebrations>();
    final entry = _repo.entryFor(widget.day);
    _lastText = entry?.text ?? '';
    _text = TextEditingController(text: _lastText)
      ..selection = TextSelection.collapsed(offset: _lastText.length)
      ..addListener(_onTextChanged);
    _mood = entry?.mood;
    _prompt = promptFor(
      widget.day,
      today: today(),
      playful: context.read<SettingsController>().playfulPrompts,
      hasEntry: _lastText.trim().isNotEmpty,
    );
    _wasWrittenToday = _repo.hasEntry(today());
    final words = countWords(_lastText);
    _milestone = _wordMilestones.where((m) => words >= m.$1).length;
    _focusOnOpen = _isToday || _lastText.trim().isEmpty;
    _focus.addListener(_onFocusChanged);
    _lifecycle = AppLifecycleListener(onInactive: _flush, onHide: _flush);
    _lock.addListener(_onLockChanged);
    if (_focusOnOpen) WidgetsBinding.instance.addPostFrameCallback((_) => _focusEditor());
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    // Saving and cheering notify listeners, which isn't allowed while the
    // widget tree is being torn down, so both wait for a microtask.
    if (_dirty && !_deleted) {
      _dirty = false;
      final repo = _repo, day = widget.day, text = _text.text, mood = _mood;
      Future.microtask(() => repo.save(day, text: text, mood: mood));
    }
    _celebrate(deferred: true);
    _lock.removeListener(_onLockChanged);
    _lifecycle.dispose();
    _debounce?.cancel();
    _bubbleTimer?.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _focusEditor() {
    if (!mounted || _lock.locked) return;
    _focus.requestFocus();
    // On a cold start the first "show keyboard" request can arrive before the
    // window has focus, so nudge it once more.
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted && _focus.hasFocus && !_lock.locked) {
        SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      }
    });
  }

  void _onFocusChanged() {
    // Inky looks at the page while you type.
    if (mounted) setState(() {});
  }

  void _onLockChanged() {
    if (!mounted) return;
    if (_lock.locked) {
      _focus.unfocus();
    } else if (_focusOnOpen && (ModalRoute.of(context)?.isCurrent ?? false)) {
      _focusEditor();
    }
  }

  void _onTextChanged() {
    if (_text.text == _lastText) return;
    _lastText = _text.text;
    _markDirty();
    final words = countWords(_lastText);
    if (_milestone < _wordMilestones.length && words >= _wordMilestones[_milestone].$1) {
      _say(_wordMilestones[_milestone].$2);
      _milestone++;
      HapticFeedback.lightImpact();
    }
  }

  void _markDirty() {
    _dirty = true;
    if (_status != _SaveStatus.editing) setState(() => _status = _SaveStatus.editing);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _flush);
  }

  Future<void> _flush() async {
    _debounce?.cancel();
    if (!_dirty || _deleted) return;
    _dirty = false;
    try {
      await _repo.save(widget.day, text: _text.text, mood: _mood);
      if (mounted) setState(() => _status = _SaveStatus.saved);
    } catch (e) {
      _dirty = true;
      if (mounted) setState(() => _status = _SaveStatus.failed);
    }
  }

  /// Streaks, today's page and new stickers get their moment once we leave.
  void _celebrate({bool deferred = false}) {
    if (_celebrated || _deleted) return;
    _celebrated = true;
    final repo = _repo, celebrations = _celebrations, day = widget.day, isToday = _isToday;
    final wasWritten = _wasWrittenToday;
    void run() => celebrations.afterWriting(repo, firstToday: isToday && !wasWritten && repo.hasEntry(day));
    deferred ? Future.microtask(run) : run();
  }

  void _say(String text) {
    _inky.currentState?.hop();
    setState(() => _bubble = text);
    _bubbleTimer?.cancel();
    _bubbleTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _bubble = null);
    });
  }

  void _rollPrompt() {
    HapticFeedback.selectionClick();
    setState(() => _prompt = rollPrompt(widget.day, today: today(), current: _prompt, random: _random));
    _inky.currentState?.hop();
  }

  Future<void> _done() async {
    await _flush();
    if (mounted) await Navigator.of(context).maybePop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Text('🗑️', style: TextStyle(fontSize: 32)),
        title: const Text('Tear out this page?'),
        content: Text('Everything you wrote for ${formatLongSmart(widget.day)} will be gone. This can’t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tear it out')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _deleted = true;
    _debounce?.cancel();
    await _repo.delete(widget.day);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('Page torn out 🗑️')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final settings = context.watch<SettingsController>();
    final hasEntry = context.select<EntryRepository, bool>((r) => r.hasEntry(widget.day));
    final mood = moodFor(_mood);
    final paper = dark ? scheme.surface : Color.alphaBlend(const Color(0x1FFFD9A0), scheme.surface);
    final wash = mood == null ? paper : Color.alphaBlend(mood.color.withValues(alpha: dark ? 0.09 : 0.13), paper);
    final style = writingStyle(settings.writingFont, settings.fontSize).copyWith(color: scheme.onSurface);
    final lineHeight = style.fontSize! * style.height!;

    return PopScope(
      onPopInvokedWithResult: (_, _) {
        _flush();
        _celebrate();
      },
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: wash),
        duration: const Duration(milliseconds: 450),
        builder: (context, background, child) => Scaffold(
          backgroundColor: background,
          appBar: AppBar(
            backgroundColor: background,
            title: Text(relativeDayLabel(widget.day, today())),
            actions: [
              if (hasEntry)
                IconButton(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Delete entry',
                ),
              Padding(
                padding: const EdgeInsets.only(right: 12, left: 4),
                child: FilledButton.icon(
                  onPressed: _done,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Done'),
                ),
              ),
            ],
          ),
          body: child,
        ),
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  _focus.requestFocus();
                  _text.selection = TextSelection.collapsed(offset: _text.text.length);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(28, 0, 22, 48),
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 76),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, a) => FadeTransition(
                                  opacity: a,
                                  child: SlideTransition(
                                    position: a.drive(Tween(begin: const Offset(0, 0.3), end: Offset.zero)),
                                    child: child,
                                  ),
                                ),
                                child: Text(
                                  _prompt,
                                  key: ValueKey(_prompt),
                                  style: handStyle(36, color: scheme.onSurface, height: 1.05),
                                ),
                              ),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      formatLong(widget.day),
                                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _rollPrompt,
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.casino_outlined, size: 20),
                                    tooltip: 'Ask me something else',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Inky(
                            key: _inky,
                            size: 70,
                            face: mood == null ? InkyFace.happy : faceForMood(mood.value),
                            look: _focus.hasFocus ? const Offset(-0.6, 0.8) : Offset.zero,
                            onTap: () => _say(_encouragements[_random.nextInt(_encouragements.length)]),
                          ),
                        ),
                        Positioned(
                          right: 72,
                          top: 10,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            switchInCurve: Curves.elasticOut,
                            transitionBuilder: (child, a) =>
                                ScaleTransition(scale: a, alignment: Alignment.centerRight, child: child),
                            child: _bubble == null
                                ? const SizedBox.shrink()
                                : ConstrainedBox(
                                    key: ValueKey(_bubble),
                                    constraints: const BoxConstraints(maxWidth: 220),
                                    child: SpeechBubble(
                                      tail: BubbleTail.right,
                                      child: Text(_bubble!, style: handStyle(20, color: scheme.onSurface)),
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    MoodPicker(
                      value: _mood,
                      onChanged: (v) {
                        setState(() => _mood = v);
                        _markDirty();
                      },
                    ),
                    const SizedBox(height: 14),
                    CustomPaint(
                      painter: _RuledPaper(
                        lineHeight: lineHeight,
                        line: dark ? scheme.onSurface.withValues(alpha: 0.10) : const Color(0x4D7F9CCB),
                        margin: dark ? const Color(0x40EF9A9A) : const Color(0x80EF9A9A),
                      ),
                      child: TextField(
                        controller: _text,
                        focusNode: _focus,
                        maxLines: null,
                        minLines: 10,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        scrollPadding: const EdgeInsets.only(bottom: 120),
                        style: style,
                        strutStyle: StrutStyle(
                          fontFamily: style.fontFamily,
                          fontSize: style.fontSize,
                          height: style.height,
                          forceStrutHeight: true,
                        ),
                        cursorColor: scheme.primary,
                        decoration: InputDecoration.collapsed(
                          hintText: hintFor(widget.day),
                          hintStyle: style.copyWith(color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _Footer(text: _text, status: _status, showWords: settings.showWordCount),
          ],
        ),
      ),
    );
  }
}

/// Notebook lines (and the red margin) behind the text.
class _RuledPaper extends CustomPainter {
  _RuledPaper({required this.lineHeight, required this.line, required this.margin});

  final double lineHeight;
  final Color line;
  final Color margin;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = line
      ..strokeWidth = 1.2;
    for (var y = lineHeight * 0.82; y < size.height + 2; y += lineHeight) {
      canvas.drawLine(Offset(-28, y), Offset(size.width + 22, y), linePaint);
    }
    canvas.drawLine(
      Offset(-12, -6),
      Offset(-12, size.height + 6),
      Paint()
        ..color = margin
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_RuledPaper old) => old.lineHeight != lineHeight || old.line != line || old.margin != margin;
}

class _Footer extends StatelessWidget {
  const _Footer({required this.text, required this.status, required this.showWords});

  final TextEditingController text;
  final _SaveStatus status;
  final bool showWords;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant);
    final (IconData? icon, String label) = switch (status) {
      _SaveStatus.idle => (null, ''),
      _SaveStatus.editing => (Icons.edit_rounded, 'Writing…'),
      _SaveStatus.saved => (Icons.check_circle_rounded, 'Saved'),
      _SaveStatus.failed => (Icons.error_outline_rounded, 'Couldn’t save, will retry'),
    };

    return Material(
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Row(
                  key: ValueKey(status),
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: 16,
                        color: status == _SaveStatus.failed ? scheme.error : scheme.primary,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(label, style: style),
                  ],
                ),
              ),
              const Spacer(),
              if (showWords)
                ListenableBuilder(
                  listenable: text,
                  builder: (context, _) {
                    final n = countWords(text.text);
                    return Text('$n ${n == 1 ? 'word' : 'words'}', style: style);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
