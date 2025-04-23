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
String? validateEmail(String email) {
  final regex = RegExp(r'^[\\w-\\.]+@([\\w-]+\\.)+[\\w-]{2,4}\$');
  if (!regex.hasMatch(email)) return 'Invalid email format';
  return null;
}

String? validateUsername(String username) {
  if (username.length < 3) return 'Username must be at least 3 characters';
  return null;
}
