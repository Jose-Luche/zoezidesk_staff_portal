import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/api/staff_api.dart';
import '../../data/models/members.dart';
import '../../shared/widgets/async_view.dart';
import '../desk/desk_providers.dart';

/// Picks photos (a provider so tests can replace it).
final imagePickerProvider = Provider<ImagePicker>((_) => ImagePicker());

/// Take, choose or remove a member's photo. Photos are scaled down on the
/// phone first: the desk only ever shows them small.
Future<void> changeMemberPhoto(BuildContext context, WidgetRef ref, MemberCard member) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.photo_camera_rounded),
          title: const Text('Take a photo'),
          onTap: () => Navigator.pop(context, 'camera'),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_rounded),
          title: const Text('Choose from the phone'),
          onTap: () => Navigator.pop(context, 'gallery'),
        ),
        if (member.photoUrl != null)
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded),
            title: const Text('Remove photo'),
            onTap: () => Navigator.pop(context, 'remove'),
          ),
      ]),
    ),
  );
  if (choice == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final api = ref.read(staffApiProvider);
  try {
    if (choice == 'remove') {
      await api.removeMemberPhoto(member.id);
    } else {
      final picked = await ref.read(imagePickerProvider).pickImage(
            source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
            preferredCameraDevice: CameraDevice.rear,
            maxWidth: 800,
            maxHeight: 800,
            imageQuality: 80,
          );
      if (picked == null) return;
      messenger.showSnackBar(const SnackBar(content: Text('Saving photo…')));
      await api.uploadMemberPhoto(member.id, picked.path);
    }
    memberDataChanged(ref);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(choice == 'remove' ? 'Photo removed.' : 'Photo saved.')));
  } on PlatformException {
    messenger.showSnackBar(const SnackBar(
      content: Text("The camera couldn't open. Allow camera access in the phone's settings, or choose a photo instead."),
    ));
  } catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(failureMessage(e))));
  }
}
