import 'package:flutter/material.dart';
import '../core/constants.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool outlined;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.label,
    this.onTap,
    this.loading = false,
    this.outlined = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    const primary = Color(AppConstants.primaryColorValue);
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: loading ? null : onTap,
              icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
              label: loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: BorderSide(color: primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            )
          : ElevatedButton.icon(
              onPressed: loading ? null : onTap,
              icon: icon != null ? Icon(icon, size: 18, color: Colors.white)
                  : const SizedBox.shrink(),
              label: loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(label,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600,
                          fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
    );
  }
}
