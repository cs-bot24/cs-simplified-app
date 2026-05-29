import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool outlined;
  final IconData? icon;
  final Color? color;

  const AppButton({super.key, required this.label, this.onTap,
      this.loading = false, this.outlined = false, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: double.infinity, height: 52,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: loading ? null : onTap,
              icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
              label: loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: c, side: BorderSide(color: c),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )
          : ElevatedButton.icon(
              onPressed: loading ? null : onTap,
              icon: icon != null
                  ? Icon(icon, size: 18, color: Colors.white)
                  : const SizedBox.shrink(),
              label: loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(label, style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: c, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
    );
  }
}
