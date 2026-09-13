import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/theme.dart';
import '../../config/enums.dart';
import '../../config/extensions.dart';
import '../../providers/auth_provider.dart';
import '../../services/app_media_service.dart';

class RegisterScreen extends HookConsumerWidget {
  final Function(String?) onErrorUpdate;

  const RegisterScreen({super.key, required this.onErrorUpdate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);

    // Registration Form Controllers
    final schoolNameCtrl = useTextEditingController();
    final schoolCodeCtrl = useTextEditingController();
    final addressCtrl = useTextEditingController();
    final phoneCtrl = useTextEditingController();
    final emailCtrl = useTextEditingController();
    final websiteCtrl = useTextEditingController();
    final principalCtrl = useTextEditingController();
    final establishedCtrl = useTextEditingController();
    final taglineCtrl = useTextEditingController();
    final idCardFooterCtrl = useTextEditingController();
    final regUsernameCtrl = useTextEditingController();
    final regPasswordCtrl = useTextEditingController();
    final regConfirmPasswordCtrl = useTextEditingController();
    final regPinCtrl = useTextEditingController();
    final regConfirmPinCtrl = useTextEditingController();

    final logoPath = useState<String?>(null);

    final formKey = useMemoized(() => GlobalKey<FormState>());
    final obscurePassword = useState<bool>(true);
    final obscurePin = useState<bool>(true);

    Future<void> pickLogo() async {
      try {
        final savedPath = await AppMediaService.pickAndSaveLogo();
        if (savedPath != null && context.mounted) {
          logoPath.value = savedPath;
        }
      } catch (e) {
        if (context.mounted) {
          context.showSnackbar(
            'Could not pick logo: $e',
            type: MessageType.error,
          );
        }
      }
    }

    void removeLogo() {
      logoPath.value = null;
    }

    void submitRegister() async {
      onErrorUpdate(null);
      if (!formKey.currentState!.validate()) return;
      formKey.currentState?.save();

      if (regPasswordCtrl.text != regConfirmPasswordCtrl.text) {
        onErrorUpdate('Passwords do not match');
        return;
      }

      final pin = regPinCtrl.text.trim();
      final confirmPin = regConfirmPinCtrl.text.trim();
      if (pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
        onErrorUpdate('Security PIN must be exactly 4 numeric digits');
        return;
      }
      if (pin != confirmPin) {
        onErrorUpdate('4-digit PINs do not match');
        return;
      }

      final success = await ref
          .read(authStateProvider.notifier)
          .registerSchool(
            name: schoolNameCtrl.text,
            code: schoolCodeCtrl.text,
            address: addressCtrl.text,
            phone: phoneCtrl.text,
            email: emailCtrl.text,
            website: websiteCtrl.text,
            principalName: principalCtrl.text,
            establishedYear: establishedCtrl.text,
            logoPath: logoPath.value,
            adminUsername: regUsernameCtrl.text,
            password: regPasswordCtrl.text,
            pin: pin,
            tagline: taglineCtrl.text,
            idCardFooter: idCardFooterCtrl.text,
          );

      if (!success && context.mounted) {
        final error = ref.read(authStateProvider).errorMessage;
        if (error != null) {
          onErrorUpdate(error);
        }
      }
    }

    final isNarrow = MediaQuery.of(context).size.width < 700;

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section: Institution Details
          // 0. School Logo Upload Section
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.surfaceContainerHighest
                            .withAlpha(90),
                        border: Border.all(
                          color: theme.colorScheme.primary.withAlpha(120),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withAlpha(30),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child:
                            logoPath.value != null &&
                                    File(logoPath.value!).existsSync()
                                ? Image.file(
                                  File(logoPath.value!),
                                  fit: BoxFit.cover,
                                )
                                : Center(
                                  child: Icon(
                                    Icons.school_rounded,
                                    size: 42,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: pickLogo,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(40),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: pickLogo,
                      icon: const Icon(Icons.upload_rounded, size: 15),
                      label: Text(
                        logoPath.value == null
                            ? 'Upload School Logo'
                            : 'Change Logo',
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (logoPath.value != null) ...[
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: removeLogo,
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 15,
                          color: theme.colorScheme.error,
                        ),
                        label: Text(
                          'Remove',
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 1. Institution Details
          Row(
            children: [
              Icon(
                Icons.account_balance_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'INSTITUTION DETAILS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (isNarrow) ...[
            TextFormField(
              controller: schoolNameCtrl,
              decoration: InputDecoration(
                labelText: 'School / College Name *',
                hintText: 'e.g. Pragyan Academy',
                prefixIcon: const Icon(Icons.school_outlined),
                border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
              ),
              validator:
                  (val) =>
                      val == null || val.trim().isEmpty
                          ? 'School name is required'
                          : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: schoolCodeCtrl,
              decoration: InputDecoration(
                labelText: 'EMIS / EIMS Code *',
                hintText: 'e.g. EMIS-2081-001 or SCH-001',
                prefixIcon: const Icon(Icons.tag_rounded),
                border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
              ),
              validator:
                  (val) =>
                      val == null || val.trim().isEmpty
                          ? 'EMIS / School code required'
                          : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: establishedCtrl,
              decoration: InputDecoration(
                labelText: 'Year of Establishment *',
                hintText: 'e.g. 2052 BS (1995 AD)',
                prefixIcon: const Icon(Icons.calendar_today_outlined),
                border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
              ),
              validator:
                  (val) =>
                      val == null || val.trim().isEmpty
                          ? 'Establishment year required'
                          : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: principalCtrl,
              decoration: InputDecoration(
                labelText: 'Principal / Headmaster Name',
                hintText: 'e.g. Dr. Ramesh Sharma',
                prefixIcon: const Icon(Icons.person_pin_outlined),
                border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: schoolNameCtrl,
                    decoration: InputDecoration(
                      labelText: 'School / College Name *',
                      hintText: 'e.g. Pragyan Academy',
                      prefixIcon: const Icon(Icons.school_outlined),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.roundedMd,
                      ),
                    ),
                    validator:
                        (val) =>
                            val == null || val.trim().isEmpty
                                ? 'School name is required'
                                : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: schoolCodeCtrl,
                    decoration: InputDecoration(
                      labelText: 'EMIS / EIMS Code *',
                      hintText: 'e.g. EMIS-2081-001',
                      prefixIcon: const Icon(Icons.tag_rounded),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.roundedMd,
                      ),
                    ),
                    validator:
                        (val) =>
                            val == null || val.trim().isEmpty
                                ? 'EMIS code required'
                                : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: establishedCtrl,
                    decoration: InputDecoration(
                      labelText: 'Year of Establishment *',
                      hintText: 'e.g. 2052 BS (1995 AD)',
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.roundedMd,
                      ),
                    ),
                    validator:
                        (val) =>
                            val == null || val.trim().isEmpty
                                ? 'Establishment year required'
                                : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: principalCtrl,
                    decoration: InputDecoration(
                      labelText: 'Principal / Headmaster Name',
                      hintText: 'e.g. Dr. Ramesh Sharma',
                      prefixIcon: const Icon(Icons.person_pin_outlined),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.roundedMd,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),

          // 2. Contact & Location
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'CONTACT & LOCATION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (isNarrow) ...[
            TextFormField(
              controller: addressCtrl,
              decoration: InputDecoration(
                labelText: 'Address / Campus Location *',
                hintText: 'e.g. Kathmandu, Nepal',
                prefixIcon: const Icon(Icons.map_outlined),
                border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
              ),
              validator:
                  (val) =>
                      val == null || val.trim().isEmpty
                          ? 'Address is required'
                          : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: phoneCtrl,
              decoration: InputDecoration(
                labelText: 'Phone Number *',
                hintText: 'e.g. +977-1-4567890',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
              ),
              validator:
                  (val) =>
                      val == null || val.trim().isEmpty
                          ? 'Phone number is required'
                          : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: emailCtrl,
              decoration: InputDecoration(
                labelText: 'Official Email',
                hintText: 'info@school.edu.np',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: websiteCtrl,
              decoration: InputDecoration(
                labelText: 'Official Website',
                hintText: 'www.school.edu.np',
                prefixIcon: const Icon(Icons.language_outlined),
                border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: addressCtrl,
                    decoration: InputDecoration(
                      labelText: 'Address / Campus Location *',
                      hintText: 'e.g. Kathmandu, Nepal',
                      prefixIcon: const Icon(Icons.map_outlined),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.roundedMd,
                      ),
                    ),
                    validator:
                        (val) =>
                            val == null || val.trim().isEmpty
                                ? 'Address is required'
                                : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: phoneCtrl,
                    decoration: InputDecoration(
                      labelText: 'Phone Number *',
                      hintText: 'e.g. +977-1-4567890',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.roundedMd,
                      ),
                    ),
                    validator:
                        (val) =>
                            val == null || val.trim().isEmpty
                                ? 'Phone number is required'
                                : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: emailCtrl,
                    decoration: InputDecoration(
                      labelText: 'Official Email',
                      hintText: 'info@school.edu.np',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.roundedMd,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: websiteCtrl,
                    decoration: InputDecoration(
                      labelText: 'Official Website',
                      hintText: 'www.school.edu.np',
                      prefixIcon: const Icon(Icons.language_outlined),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.roundedMd,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),

          // Section: Administrator Credentials
          // 3. Branding & ID Configuration
          Row(
            children: [
              Icon(
                Icons.badge_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'MOTTO & ID CARD SETTINGS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: taglineCtrl,
            decoration: InputDecoration(
              labelText: 'Motto / Tagline',
              hintText: 'e.g. Knowledge, Character, Excellence',
              prefixIcon: const Icon(Icons.format_quote_rounded),
              border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: idCardFooterCtrl,
            decoration: InputDecoration(
              labelText: 'Student ID Card Footer Note',
              hintText: 'e.g. This card is non-transferable...',
              prefixIcon: const Icon(Icons.notes_rounded),
              border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
            ),
          ),
          const SizedBox(height: 20),

          // 4. Administrator Credentials & 4-Digit PIN
          Row(
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'ADMINISTRATOR ACCESS & 4-DIGIT PIN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: regUsernameCtrl,
            decoration: InputDecoration(
              labelText: 'Admin Username *',
              hintText: 'e.g. admin',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
            ),
            validator:
                (val) =>
                    val == null || val.trim().isEmpty
                        ? 'Admin username required'
                        : null,
          ),
          const SizedBox(height: 12),

          if (isNarrow) ...[
            TextFormField(
              controller: regPasswordCtrl,
              obscureText: obscurePassword.value,
              decoration: InputDecoration(
                labelText: 'Admin Password *',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword.value
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed:
                      () => obscurePassword.value = !obscurePassword.value,
                ),
                border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
              ),
              validator:
                  (val) =>
                      (val == null || val.length < 4)
                          ? 'Minimum 4 characters'
                          : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: regConfirmPasswordCtrl,
              obscureText: obscurePassword.value,
              decoration: InputDecoration(
                labelText: 'Confirm Password *',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
              ),
              validator:
                  (val) =>
                      (val == null || val.isEmpty)
                          ? 'Please confirm password'
                          : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: regPinCtrl,
              obscureText: obscurePin.value,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: InputDecoration(
                labelText: '4-Digit Security PIN *',
                hintText: 'e.g. 1234',
                prefixIcon: const Icon(Icons.pin_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePin.value
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => obscurePin.value = !obscurePin.value,
                ),
                border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
              ),
              validator:
                  (val) =>
                      (val == null || val.length != 4)
                          ? 'Must be exactly 4 digits'
                          : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: regConfirmPinCtrl,
              obscureText: obscurePin.value,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: InputDecoration(
                labelText: 'Confirm 4-Digit PIN *',
                prefixIcon: const Icon(Icons.pin_outlined),
                border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
              ),
              validator:
                  (val) =>
                      (val == null || val.length != 4)
                          ? 'Must be exactly 4 digits'
                          : null,
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: regPasswordCtrl,
                    obscureText: obscurePassword.value,
                    decoration: InputDecoration(
                      labelText: 'Admin Password *',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword.value
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed:
                            () =>
                                obscurePassword.value = !obscurePassword.value,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.roundedMd,
                      ),
                    ),
                    validator:
                        (val) =>
                            (val == null || val.length < 4)
                                ? 'Minimum 4 characters'
                                : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: regConfirmPasswordCtrl,
                    obscureText: obscurePassword.value,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password *',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.roundedMd,
                      ),
                    ),
                    validator:
                        (val) =>
                            (val == null || val.isEmpty)
                                ? 'Please confirm password'
                                : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: regPinCtrl,
                    obscureText: obscurePin.value,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: InputDecoration(
                      labelText: '4-Digit Security PIN *',
                      hintText: 'e.g. 1234',
                      prefixIcon: const Icon(Icons.pin_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePin.value
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => obscurePin.value = !obscurePin.value,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.roundedMd,
                      ),
                    ),
                    validator:
                        (val) =>
                            (val == null || val.length != 4)
                                ? 'Must be 4 digits'
                                : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: regConfirmPinCtrl,
                    obscureText: obscurePin.value,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Confirm 4-Digit PIN *',
                      prefixIcon: const Icon(Icons.pin_outlined),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.roundedMd,
                      ),
                    ),
                    validator:
                        (val) =>
                            (val == null || val.length != 4)
                                ? 'Must be 4 digits'
                                : null,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedMd),
              elevation: 2,
            ),
            onPressed: authState.isLoading ? null : submitRegister,
            child:
                authState.isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : const Text(
                      'Register Institution & Enter SMS',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
