import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final Widget? suffix;

  const AppTextField({super.key, required this.label, required this.controller,
      this.hint, this.obscure = false, this.keyboardType = TextInputType.text,
      this.validator, this.prefixIcon, this.suffix});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller, obscureText: obscure,
      keyboardType: keyboardType, validator: validator,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
        suffix: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
