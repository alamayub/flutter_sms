// import 'package:flutter/material.dart';

// import '../../config/theme.dart';

// enum AppFieldType {
//   text,
//   password,
//   description,
//   number,
//   decimal,
//   email,
//   phone,
//   url,
// }

// class AppTextField extends StatelessWidget {
//   final TextEditingController? controller;

//   final AppFieldType type;

//   final TextInputType? keyboardType;

//   final String? label;
//   final String? hint;

//   final Widget? prefixIcon;
//   final Widget? suffixIcon;

//   final bool required;
//   final bool enabled;
//   final bool readOnly;
//   final bool obscureText;

//   final int? maxLines;
//   final int? minLines;
//   final int? maxLength;

//   final TextInputAction? textInputAction;
//   final TextCapitalization textCapitalization;

//   final String? Function(String?)? validator;
//   final ValueChanged<String>? onChanged;
//   final VoidCallback? onTap;
//   final FormFieldSetter<String>? onSaved;

//   final EdgeInsetsGeometry? contentPadding;

//   final InputBorder? border;
//   final InputBorder? focusedBorder;
//   final InputBorder? errorBorder;

//   const AppTextField({
//     super.key,
//     this.controller,
//     this.type = AppFieldType.text,
//     this.keyboardType,
//     this.label,
//     this.hint,
//     this.prefixIcon,
//     this.suffixIcon,
//     this.required = false,
//     this.enabled = true,
//     this.readOnly = false,
//     this.obscureText = false,
//     this.maxLines,
//     this.minLines,
//     this.maxLength,
//     this.textInputAction,
//     this.textCapitalization = TextCapitalization.none,
//     this.validator,
//     this.onChanged,
//     this.onTap,
//     this.onSaved,
//     this.contentPadding,
//     this.border,
//     this.focusedBorder,
//     this.errorBorder,
//   });

//   TextInputType get _keyboardType {
//     if (keyboardType != null) return keyboardType!;

//     switch (type) {
//       case AppFieldType.number:
//         return TextInputType.number;

//       case AppFieldType.decimal:
//         return const TextInputType.numberWithOptions(decimal: true);

//       case AppFieldType.email:
//         return TextInputType.emailAddress;

//       case AppFieldType.phone:
//         return TextInputType.phone;

//       case AppFieldType.url:
//         return TextInputType.url;

//       case AppFieldType.text:
//       case AppFieldType.password:
//       case AppFieldType.description:
//         return TextInputType.text;
//     }
//   }

//   String? get _defaultLabel {
//     switch (type) {
//       case AppFieldType.password:
//         return 'Password';

//       case AppFieldType.email:
//         return 'Email';

//       case AppFieldType.number:
//         return 'Number';

//       case AppFieldType.decimal:
//         return 'Amount';

//       case AppFieldType.phone:
//         return 'Phone Number';

//       case AppFieldType.description:
//         return 'Description';

//       case AppFieldType.url:
//         return 'URL';

//       case AppFieldType.text:
//         return null;
//     }
//   }

//   int? get _maxLines {
//     if (maxLines != null) return maxLines;

//     if (type == AppFieldType.description) {
//       return 5;
//     }

//     return 1;
//   }

//   bool get _obscureText {
//     return obscureText || type == AppFieldType.password;
//   }

//   String? _validate(String? value) {
//     final val = value?.trim() ?? '';

//     // Required validation
//     if (required && val.isEmpty) {
//       return '${label ?? _defaultLabel ?? 'This field'} is required';
//     }

//     // Don't validate optional empty fields.
//     if (val.isEmpty) return null;

//     // Built-in validation
//     switch (type) {
//       case AppFieldType.email:
//         final emailRegex = RegExp(r'^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,}$');

//         if (!emailRegex.hasMatch(val)) {
//           return 'Enter a valid email address';
//         }

//       case AppFieldType.phone:
//         final phoneRegex = RegExp(r'^[0-9+\-\s()]{7,20}$');

//         if (!phoneRegex.hasMatch(val)) {
//           return 'Enter a valid phone number';
//         }

//       case AppFieldType.number:
//         if (num.tryParse(val) == null) {
//           return 'Enter a valid number';
//         }

//       case AppFieldType.decimal:
//         if (double.tryParse(val) == null) {
//           return 'Enter a valid number';
//         }

//       case AppFieldType.url:
//         final uri = Uri.tryParse(val);

//         if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
//           return 'Enter a valid URL';
//         }

//       case AppFieldType.text:
//       case AppFieldType.password:
//       case AppFieldType.description:
//         break;
//     }

//     // Custom validation
//     return validator?.call(value);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return TextFormField(
//       controller: controller,

//       enabled: enabled,
//       readOnly: readOnly,

//       obscureText: _obscureText,

//       keyboardType: _keyboardType,
//       textInputAction: textInputAction,
//       textCapitalization: textCapitalization,

//       maxLines: _obscureText ? 1 : _maxLines,
//       minLines: minLines,
//       maxLength: maxLength,

//       onChanged: onChanged,
//       onTap: onTap,
//       onSaved: onSaved,
//       validator: _validate,
//       decoration: InputDecoration(
//         labelText:
//             required
//                 ? '${label ?? _defaultLabel ?? ''} *'
//                 : label ?? _defaultLabel,
//         hintText: hint,
//         prefixIcon: prefixIcon,
//         suffixIcon: suffixIcon,
//         contentPadding: contentPadding,
//         border: border ?? OutlineInputBorder(borderRadius: AppRadius.roundedMd),
//         focusedBorder: focusedBorder,
//         errorBorder: errorBorder,
//       ),
//     );
//   }
// }
