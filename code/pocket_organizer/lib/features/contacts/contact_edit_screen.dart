import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation.dart';
import '../../core/result.dart';
import 'contact.dart';
import 'contact_avatar.dart';
import 'contact_validation.dart';
import 'contacts_view_model.dart';
import 'photos.dart';

// #docregion contactedit
class ContactEditScreen extends StatefulWidget {
  const ContactEditScreen({super.key, this.contactId});
  final int? contactId;

  @override
  State<ContactEditScreen> createState() => _ContactEditScreenState();
}

class _ContactEditScreenState extends State<ContactEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  Contact? _existing;
  String? _photoPath;
  String? _newPhotoPath; // picked in this session, not yet attached to a save
  bool _loading = true;
  bool _missing = false;
  bool _saving = false;
  bool _saved = false;
  late final ContactsViewModel _vm = context.read<ContactsViewModel>();

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final id = widget.contactId;
    if (id != null) {
      final found = await _vm.find(id);
      if (!mounted) return;
      if (found == null) {
        setState(() {
          _loading = false;
          _missing = true;
        });
        return;
      }
      _existing = found;
      _name.text = found.name;
      _phone.text = found.phone;
      _email.text = found.email;
      _photoPath = found.photoPath;
    }
    setState(() => _loading = false);
  }

  Future<void> _choosePhoto(PhotoOrigin origin) async {
    final result = await _vm.choosePhoto(origin);
    if (!mounted) return;
    switch (result) {
      case Ok(value: null):
        break; // cancelled: keep what we had
      case Ok(:final value?):
        // A second pick in the same session replaces the first one.
        final previous = _newPhotoPath;
        if (previous != null) _vm.discardPhoto(previous);
        setState(() {
          _photoPath = value;
          _newPhotoPath = value;
        });
      case Err(:final message):
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _showPhotoMenu() {
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _choosePhoto(PhotoOrigin.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from your photos'),
              onTap: () {
                Navigator.pop(sheetContext);
                _choosePhoto(PhotoOrigin.gallery);
              },
            ),
            if (_photoPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove the photo'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  final fresh = _newPhotoPath;
                  if (fresh != null) _vm.discardPhoto(fresh);
                  setState(() {
                    _photoPath = null;
                    _newPhotoPath = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final result = await _vm.save(
      existing: _existing,
      name: _name.text,
      phone: _phone.text,
      email: _email.text,
      photoPath: _photoPath,
    );
    if (!mounted) return;
    switch (result) {
      case Ok():
        _saved = true;
        context.closeEditor('/contacts');
      case Err(:final message):
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  void dispose() {
    // A picture that was chosen but never saved is garbage: delete it.
    final fresh = _newPhotoPath;
    if (!_saved && fresh != null) _vm.discardPhoto(fresh);
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contactId == null ? 'New contact' : 'Edit contact'),
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
          ? const Center(child: Text('This contact no longer exists.'))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: Stack(
                      children: [
                        ContactAvatar(
                          contact: Contact(
                            name: _name.text,
                            photoPath: _photoPath,
                          ),
                          radius: 48,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: IconButton.filled(
                            tooltip: 'Change photo',
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: _showPhotoMenu,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: validateName,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    onChanged: (_) => setState(() {}), // refresh the initials
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    validator: validatePhone,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: validateEmail,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                ],
              ),
            ),
    );
  }
}
// #enddocregion contactedit
