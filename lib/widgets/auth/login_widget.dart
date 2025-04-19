import 'package:flutter/material.dart';

class LoginWidget extends StatelessWidget {
  const LoginWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextFormField(),
          const SizedBox(height: 12),
          TextFormField(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(onPressed: () {}, child: const Text('Login')),
          ),
        ],
      ),
    );
  }
}
