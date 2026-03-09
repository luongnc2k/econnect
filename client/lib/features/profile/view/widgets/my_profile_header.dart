import 'dart:io';

import 'package:client/features/auth/model/user_model.dart';
import 'package:flutter/material.dart';

class MyProfileHeader extends StatelessWidget {
  final UserModel profile;
  final VoidCallback? onEditAvatar;
  final bool isUploadingAvatar;

  const MyProfileHeader({
    super.key,
    required this.profile,
    this.onEditAvatar,
    this.isUploadingAvatar = false,
  });

  bool _isNetworkUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final avatar = profile.avatarUrl;
    final hasAvatar = avatar != null && avatar.trim().isNotEmpty;

    ImageProvider? imageProvider;
    if (hasAvatar) {
      if (_isNetworkUrl(avatar!)) {
        imageProvider = NetworkImage(avatar);
      } else {
        imageProvider = FileImage(File(avatar));
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 56,
                backgroundImage: imageProvider,
                child: !hasAvatar ? const Icon(Icons.person, size: 62) : null,
              ),
              if (onEditAvatar != null)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: InkWell(
                    onTap: isUploadingAvatar ? null : onEditAvatar,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: isUploadingAvatar
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt, size: 18),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            profile.fullName,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Chip(label: Text(profile.role == 'teacher' ? 'Teacher' : 'Student')),
        ],
      ),
    );
  }
}
