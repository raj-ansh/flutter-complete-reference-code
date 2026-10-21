import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/list_screen_body.dart';
import 'contact.dart';
import 'contact_avatar.dart';
import 'contacts_view_model.dart';

// #docregion contactsscreen
class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ContactsViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'contacts-fab',
        onPressed: () => context.push('/contacts/new'),
        tooltip: 'New contact',
        child: const Icon(Icons.person_add),
      ),
      body: ListScreenBody<Contact>(
        state: vm.state,
        onRetry: vm.load,
        onSearch: vm.search,
        searchHint: 'Search contacts',
        emptyIcon: Icons.people_outline,
        emptyTitle: 'No contacts yet',
        emptyHint: 'Tap the button to add someone.',
        itemBuilder: (context, contact) => _ContactTile(contact: contact),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact});
  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ContactsViewModel>();
    final details = [contact.phone, contact.email].where((s) => s.isNotEmpty);
    return Dismissible(
      key: ValueKey(contact.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete),
      ),
      onDismissed: (_) async {
        final messenger = ScaffoldMessenger.of(context);
        final removed = await vm.delete(contact);
        if (removed == null) return;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Deleted ${contact.name}'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => vm.undoDelete(removed),
              ),
            ),
          );
      },
      child: ListTile(
        leading: ContactAvatar(contact: contact),
        title: Text(contact.name),
        subtitle: details.isEmpty ? null : Text(details.join(' · ')),
        onTap: () => context.push('/contacts/${contact.id}'),
      ),
    );
  }
}
// #enddocregion contactsscreen
