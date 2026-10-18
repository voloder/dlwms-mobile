import 'package:flutter/material.dart';

/// Themed text field used on the login screen.
class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final IconData prefixIcon;
  final bool isPassword;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.prefixIcon,
    this.isPassword = false,
    this.enabled = true,
    this.onSubmitted,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _obscurePassword;

  @override
  void initState() {
    super.initState();
    _obscurePassword = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: widget.isPassword ? _obscurePassword : false,
      autocorrect: false,
      enableSuggestions: !widget.isPassword,
      keyboardType: widget.isPassword ? null : TextInputType.text,
      textInputAction:
          widget.isPassword ? TextInputAction.done : TextInputAction.next,
      autofillHints: [
        widget.isPassword ? AutofillHints.password : AutofillHints.username,
      ],
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        prefixIcon: Icon(widget.prefixIcon),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        suffixIcon: widget.isPassword
            ? IconButton(
                tooltip: _obscurePassword ? 'Prikaži šifru' : 'Sakrij šifru',
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              )
            : null,
      ),
    );
  }
}
