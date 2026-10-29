import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_icons.dart';
import '../../data/api/staff_api.dart';
import '../../data/models/members.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/sheet.dart';
import '../../shared/widgets/toast.dart';
import '../desk/desk_providers.dart';

/// Picks photos (a provider so tests can replace it).
final imagePickerProvider = Provider<ImagePicker>((_) => ImagePicker());

/// Take, choose or remove a member's photo. Photos are scaled down on the
/// phone first: the desk only ever shows them small.
Future<void> changeMemberPhoto(BuildContext context, WidgetRef ref, MemberCard member) async {
  final choice = await showAppSheet<String>(
    context,
    builder: (context) => SheetBody(children: [
      const SheetTitle('Photo'),
      ListTile(
        leading: const Icon(AppIcons.camera),
        title: const Text('Take a photo'),
        onTap: () => Navigator.pop(context, 'camera'),
      ),
      ListTile(
        leading: const Icon(AppIcons.gallery),
        title: const Text('Choose from the phone'),
        onTap: () => Navigator.pop(context, 'gallery'),
      ),
      if (member.photoUrl != null)
        ListTile(
          leading: const Icon(AppIcons.delete),
          title: const Text('Remove photo'),
          onTap: () => Navigator.pop(context, 'remove'),
        ),
    ]),
  );
  if (choice == null || !context.mounted) return;

  final toast = ProviderScope.containerOf(context, listen: false).read(toastProvider);
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
      toast.show('Saving photo…');
      await api.uploadMemberPhoto(member.id, picked.path);
    }
    memberDataChanged(ref);
    toast.show(choice == 'remove' ? 'Photo removed' : 'Photo saved');
  } on PlatformException {
    toast.show("The camera couldn't open. Allow camera access in the phone's settings, or choose a photo instead.");
  } catch (e) {
    toast.show(failureMessage(e));
  }
}
