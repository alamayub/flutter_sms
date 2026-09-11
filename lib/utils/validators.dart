class Validators {
  static String? requiredField(
    String? value, [
    String message = 'This field is required',
  ]) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return null; // Optional if empty
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  static String? nepaliPhone(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'Phone number is required' : null;
    }
    final clean = value.replaceAll(RegExp(r'\D'), '');
    final regex = RegExp(r'^(98|97|96)[0-9]{8}$');
    if (!regex.hasMatch(clean)) {
      return 'Enter a valid 10-digit mobile number (98XXXXXXXX / 97XXXXXXXX)';
    }
    return null;
  }

  static String? positiveNumber(
    String? value, [
    String message = 'Must be a valid positive number',
  ]) {
    if (value == null || value.trim().isEmpty) return null;
    final numVal = num.tryParse(value.trim());
    if (numVal == null || numVal < 0) {
      return message;
    }
    return null;
  }

  static String? feeAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Fee amount is required';
    }
    final numVal = num.tryParse(value.trim());
    if (numVal == null || numVal <= 0) {
      return 'Amount must be greater than 0';
    }
    return null;
  }

  static String? minLength(String? value, int min, [String? message]) {
    if (value == null || value.trim().length < min) {
      return message ?? 'Must be at least $min characters long';
    }
    return null;
  }

  static String? validateEmail(String? value) => email(value);

  static String? validatePhone(String? value) =>
      nepaliPhone(value, required: false);
}
