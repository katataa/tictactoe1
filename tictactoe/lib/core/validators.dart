String? validatePassword(String password) {
  final hasUpper = RegExp(r'[A-Z]');
  final hasLower = RegExp(r'[a-z]');
  final hasDigit = RegExp(r'\d');
  final hasSpecial = RegExp(r'[!@#\$&*~]');
  final hasMinLength = password.length >= 8;

  if (!hasMinLength || !hasUpper.hasMatch(password) || !hasLower.hasMatch(password) ||
      !hasDigit.hasMatch(password) || !hasSpecial.hasMatch(password)) {
    return 'Password must be at least 8 characters and include uppercase, lowercase, number, and special char';
  }
  return null;
}
