import 'package:flutter/foundation.dart' show immutable;

@immutable
class Strings {
  static const loading = 'Loading...';
  static const cancle = 'Cancel';
  static const submit = 'Submit';
  static const logout = 'Logout';
  static const delete = 'Delete';
  static const enable = 'Enable';
  static const dismiss = 'Dismiss';
  static const dontHaveAccount = 'Don\'t have an account? ';
  static const alreadyHaveAccount = 'Already have an account? ';
  static const login = 'Login';
  static const register = 'Sign Up';
  static const noUserFound =
      'No account found with the provided email, phone number, or username. Please check your details or sign up for a new account.';
  static const errorDesc = 'Something went wrong. Please try again!';
  static const genericAlertDescription = 'Are you sure, you want to ';
  static const registerSuccess =
      'Your account has been successfully created! Please log in to continue and explore all the features. Welcome aboard!';
  static const profileUpdate =
      'Your profile has been successfully updated. Keep your information up-to-date to enjoy a seamless experience!';
  static const unauthorized = 'Please login before proceeding!';

  static const gaurdianInfoAdded =
      'Guardian information has been added successfully!';
  static const gaurdianInfoUpdated =
      'Guardian information has been updated successfully!';
  static const addressAdded = 'Address has been added successfully!';
  static const addressUpdated = 'Address has been updated successfully!';
  const Strings._();
}

@immutable
class DbConstants {
  static const id = 'id';
  static const firstName = 'first_name';
  static const middleName = 'middle_name';
  static const lastName = 'last_name';
  static const dob = 'dob';
  static const grade = 'grade';
  static const section = 'section';
  static const rollNo = 'roll_number';
  static const address = 'address';
  static const createdBy = 'created_by';
  static const createdAt = 'created_at';
  static const updatedBy = 'updated_by';
  static const updatedAt = 'updated_at';
  const DbConstants._();
}
