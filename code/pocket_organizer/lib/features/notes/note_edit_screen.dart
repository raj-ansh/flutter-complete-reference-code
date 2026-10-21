import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation.dart';
import '../../core/result.dart';
import 'note.dart';
import 'notes_view_model.dart';

// #docregion edit
/// Creates a note (no id) or edits one (id from the route).
class NoteEditScreen extends StatefulWidget {
  const NoteEditScreen({super.key, this.noteId});
  final int? noteId;

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  Note? _existing;
  bool _loading = true;
  bool _missing = false;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final id = widget.noteId;
    if (id != null) {
      final note = await context.read<NotesViewModel>().find(id);
      if (!mounted) return;
      if (note == null) {
        setState(() {
          _loading = false;
          _missing = true;
        });
        return;
      }
      _existing = note;
      _title.text = note.title;
      _body.text = note.body;
    }
    // Only start tracking edits after the fields have their first values.
    _title.addListener(_markDirty);
    _body.addListener(_markDirty);
    setState(() => _loading = false);
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final result = await context.read<NotesViewModel>().save(
      existing: _existing,
      title: _title.text,
      body: _body.text,
    );
    if (!mounted) return;
    switch (result) {
      case Ok():
        setState(() => _dirty = false); // allow the pop below
        context.closeEditor('/');
      case Err(:final message):
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your changes to this note have not been saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => _dirty = false);
      context.closeEditor('/');
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back is allowed only when there is nothing to lose.
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.noteId == null ? 'New note' : 'Edit note'),
          actions: [
            TextButton(
              onPressed: (_saving || _loading || _missing) ? null : _save,
              child: const Text('Save'),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _missing
            ? const Center(child: Text('This note no longer exists.'))
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      style: Theme.of(context).textTheme.titleLarge,
                      decoration: const InputDecoration(
                        hintText: 'Title',
                        border: InputBorder.none,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _body,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          hintText: 'Write something…',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
// #enddocregion edit
