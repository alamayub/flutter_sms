import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/theme.dart';
import '../../config/enums.dart';
import '../../config/extensions.dart';
import '../../providers/auth_provider.dart';
import '../../services/app_media_service.dart';
import '../../widgets/auth/register_group_header.dart';
import '../../widgets/auth/upload_school_logo.dart';

class RegisterScreen extends HookConsumerWidget {
  final Function(String?) onErrorUpdate;

  const RegisterScreen({super.key, required this.onErrorUpdate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          UploadSchoolLogo(
            logoPath: logoPath.value,
            onLogoPick: pickLogo,
            onLogoRemove: removeLogo,
          ),
          const SizedBox(height: 16),

          // 1. Institution Details
          RegisterGroupHeader(
            icon: Icons.account_balance_outlined,
            title: 'INSTITUTION DETAILS',
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
          RegisterGroupHeader(
            icon: Icons.location_on_outlined,
            title: 'CONTACT & LOCATION',
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
          RegisterGroupHeader(
            icon: Icons.badge_outlined,
            title: 'MOTTO & ID CARD SETTINGS',
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
          RegisterGroupHeader(
            icon: Icons.admin_panel_settings_outlined,
            title: 'ADMINISTRATOR ACCESS & 4-DIGIT PIN',
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
              backgroundColor: context.theme.colorScheme.primary,
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
