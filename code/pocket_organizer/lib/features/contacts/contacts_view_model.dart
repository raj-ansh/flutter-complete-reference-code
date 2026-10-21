import '../../core/list_view_model.dart';
import '../../core/result.dart';
import 'contact.dart';
import 'contact_validation.dart';
import 'contacts_repository.dart';
import 'photos.dart';

// #docregion contactsvm
class ContactsViewModel extends ListViewModel<Contact> {
  ContactsViewModel(this._repository, this._picker, this._storage);

  final ContactsRepository _repository;
  final PhotoPicker _picker;
  final PhotoStorage _storage;

  @override
  Future<Result<List<Contact>>> fetch(String query) =>
      _repository.list(query: query);

  /// Validates again here even though the form already did: the view model is
  /// the last stop before storage, and other callers may not use the form.
  Future<Result<Contact>> save({
    Contact? existing,
    required String name,
    String phone = '',
    String email = '',
    String? photoPath,
  }) async {
    final problem =
        validateName(name) ?? validatePhone(phone) ?? validateEmail(email);
    if (problem != null) return Err(problem);

    final contact = (existing ?? const Contact(name: '')).copyWith(
      name: name.trim(),
      phone: phone.trim(),
      email: email.trim(),
      photoPath: () => photoPath,
    );
    final result = await _repository.save(contact);
    if (result is Ok<Contact>) {
      final old = existing?.photoPath;
      // The photo was replaced or removed: the old file is now garbage.
      if (old != null && old != photoPath) await _storage.remove(old);
      await reload();
    }
    return result;
  }

  /// Lets the user pick a picture and keeps a copy in the app's storage.
  /// Ok(null) means the user cancelled.
  Future<Result<String?>> choosePhoto(PhotoOrigin origin) async {
    final picked = await _picker.pick(origin);
    switch (picked) {
      case Err(:final message):
        return Err(message);
      case Ok(value: null):
        return const Ok(null);
      case Ok(:final value?):
        try {
          return Ok(await _storage.keep(value));
        } on Object {
          return const Err('Could not save the photo');
        }
    }
  }

  /// Removes a picture that was chosen but never attached to a saved contact.
  Future<void> discardPhoto(String path) => _storage.remove(path);

  Future<Contact?> find(int id) async {
    final result = await _repository.byId(id);
    return result is Ok<Contact?> ? result.value : null;
  }

  Future<Contact?> delete(Contact contact) async {
    final result = await _repository.delete(contact.id!);
    await afterAction(result);
    return result is Ok ? contact : null;
  }

  Future<void> undoDelete(Contact contact) async =>
      afterAction(await _repository.restore(contact));
}
// #enddocregion contactsvm
