import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';

class NotificationBadge extends StatelessWidget {
  final int count;
  final Color? backgroundColor;
  final double? size;

  const NotificationBadge({
    super.key,
    required this.count,
    this.backgroundColor,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.error,
        borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
      ),
      constraints: const BoxConstraints(maxWidth: 60),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: TextStyle(
          color: Colors.white,
          fontSize: size ?? 10,
          fontWeight: FontWeight.bold,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const StatusChip({
    super.key,
    required this.label,
    required this.backgroundColor,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.paddingMedium,
        vertical: AppDimens.paddingSmall,
      ),
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: backgroundColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
