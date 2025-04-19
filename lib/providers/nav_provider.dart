import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show Provider, StateProvider;

import '../screens/root/dashboard_screen.dart';
import '../screens/root/staffs_screen.dart';
import '../screens/root/students_screen.dart';
import '../screens/root/profile_screen.dart';

List<IconData> _navIcons = const [
  Icons.dashboard_rounded,
  Icons.people_rounded,
  Icons.people_rounded,
  Icons.person_rounded,
];
List<String> _navLabels = const ['Dashboard', 'Students', 'Staffs', 'Profile'];

List<Widget> _body = const [
  DashboardScreen(),
  StudentsScreen(),
  StaffsScreen(),
  ProfileScreen(),
];

final navLabelsProvider = Provider<List<String>>((_) => _navLabels);
final navIconsProvider = Provider<List<IconData>>((_) => _navIcons);
final rootBodyProvider = Provider<List<Widget>>((_) => _body);
final currentIndexProvider = StateProvider<int>((_) => 0);
