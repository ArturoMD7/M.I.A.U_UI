import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';

class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? placeholderText;
  final double size;
  final Color? backgroundColor;
  final Color? textColor;

  const AppAvatar({
    super.key,
    this.imageUrl,
    this.placeholderText,
    this.size = AppDimens.avatarLarge,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: backgroundColor ?? AppColors.primary.withAlpha(26),
      backgroundImage:
          imageUrl != null && imageUrl!.isNotEmpty
              ? NetworkImage(imageUrl!)
              : null,
      child:
          imageUrl == null || imageUrl!.isEmpty
              ? placeholderText != null
                  ? Text(
                    placeholderText!.isNotEmpty
                        ? placeholderText![0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: size / 2,
                      fontWeight: FontWeight.bold,
                      color: textColor ?? AppColors.primary,
                    ),
                  )
                  : Icon(
                    Icons.person,
                    size: size / 2,
                    color: textColor ?? AppColors.primary,
                  )
              : null,
    );
  }
}

class UserAvatar extends StatelessWidget {
  final String? profilePhoto;
  final String name;
  final double size;

  const UserAvatar({
    super.key,
    this.profilePhoto,
    required this.name,
    this.size = AppDimens.avatarMedium,
  });

  @override
  Widget build(BuildContext context) {
    if (profilePhoto != null && profilePhoto!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(profilePhoto!),
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primary.withAlpha(26),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: size / 2.5,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
