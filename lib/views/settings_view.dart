import 'package:all_documents_reader/core/config/app_config.dart';
import 'package:all_documents_reader/core/theme/app_theme.dart';
import 'package:all_documents_reader/services/settings_service.dart';
import 'package:flutter/material.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final SettingsService _settings = SettingsService.instance;
  String _cacheSizeStr = "...";

  @override
  void initState() {
    super.initState();
    _updateCacheSize();
  }

  Future<void> _updateCacheSize() async {
    final bytes = await _settings.getCacheSizeBytes();
    if (!mounted) return;
    setState(() {
      _cacheSizeStr = _formatBytes(bytes);
    });
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 KB";
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Settings",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore_outlined),
            tooltip: "Reset to Default",
            onPressed: () => _showResetDefaultsDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _buildAppHeaderCard(context, isDark),
          const SizedBox(height: 16),

          _buildSectionHeader(context, "Appearance & Theme"),
          _buildCardGroup(
            context,
            children: [
              ValueListenableBuilder<ThemeMode>(
                valueListenable: _settings.themeModeNotifier,
                builder: (context, themeMode, _) {
                  return _SettingsTile(
                    icon: Icons.palette_outlined,
                    iconBgColor: const Color(0xFFE8DEF8),
                    iconColor: const Color(0xFF7046A8),
                    title: "Theme Mode",
                    subtitle: _getThemeModeLabel(themeMode),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey,
                    ),
                    onTap: () => _showThemeModeDialog(context, themeMode),
                  );
                },
              ),
              _buildDivider(context),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: _settings.themeModeNotifier,
                builder: (context, themeMode, _) {
                  final isDarkMode = themeMode == ThemeMode.dark;
                  return _SettingsSwitchTile(
                    icon: Icons.dark_mode_outlined,
                    iconBgColor: const Color(0xFFE8DEF8),
                    iconColor: const Color(0xFF7046A8),
                    title: "Dark Mode",
                    subtitle: "Force dark visual appearance",
                    value: isDarkMode,
                    onChanged: (bool value) {
                      _settings.setThemeMode(
                        value ? ThemeMode.dark : ThemeMode.light,
                      );
                    },
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 20),
          _buildSectionHeader(context, "Reading Preferences"),
          _buildCardGroup(
            context,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: _settings.defaultViewModeNotifier,
                builder: (context, viewMode, _) {
                  return _SettingsTile(
                    icon: Icons.auto_stories_outlined,
                    iconBgColor: const Color(0xFFE8EEF9),
                    iconColor: const Color(0xFF3F6FA8),
                    title: "Default Viewer Mode",
                    subtitle: viewMode == 'horizontal'
                        ? "Horizontal Page Flip"
                        : "Continuous Vertical Scroll",
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey,
                    ),
                    onTap: () => _showViewModeDialog(context, viewMode),
                  );
                },
              ),
              _buildDivider(context),
              ValueListenableBuilder<bool>(
                valueListenable: _settings.keepScreenAwakeNotifier,
                builder: (context, keepAwake, _) {
                  return _SettingsSwitchTile(
                    icon: Icons.screen_lock_portrait_outlined,
                    iconBgColor: const Color(0xFFE8EEF9),
                    iconColor: const Color(0xFF3F6FA8),
                    title: "Keep Screen Awake",
                    subtitle: "Prevent display from sleeping while reading",
                    value: keepAwake,
                    onChanged: (val) => _settings.setKeepScreenAwake(val),
                  );
                },
              ),
              _buildDivider(context),
              ValueListenableBuilder<bool>(
                valueListenable: _settings.fullscreenReadingNotifier,
                builder: (context, fullscreen, _) {
                  return _SettingsSwitchTile(
                    icon: Icons.fullscreen_outlined,
                    iconBgColor: const Color(0xFFE8EEF9),
                    iconColor: const Color(0xFF3F6FA8),
                    title: "Fullscreen Reading",
                    subtitle: "Hide system bars for distraction-free view",
                    value: fullscreen,
                    onChanged: (val) => _settings.setFullscreenReading(val),
                  );
                },
              ),
              _buildDivider(context),
              ValueListenableBuilder<bool>(
                valueListenable: _settings.showPageNumbersNotifier,
                builder: (context, showNumbers, _) {
                  return _SettingsSwitchTile(
                    icon: Icons.format_list_numbered_outlined,
                    iconBgColor: const Color(0xFFE8EEF9),
                    iconColor: const Color(0xFF3F6FA8),
                    title: "Page Numbers & Progress",
                    subtitle: "Display page overlay indicator in viewer",
                    value: showNumbers,
                    onChanged: (val) => _settings.setShowPageNumbers(val),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 20),
          _buildSectionHeader(context, "Storage & File Management"),
          _buildCardGroup(
            context,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: _settings.defaultSortNotifier,
                builder: (context, sort, _) {
                  return _SettingsTile(
                    icon: Icons.sort_outlined,
                    iconBgColor: const Color(0xFFE5F3EA),
                    iconColor: const Color(0xFF3D8B5F),
                    title: "Default Sort Order",
                    subtitle: _getSortOrderLabel(sort),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey,
                    ),
                    onTap: () => _showSortOrderDialog(context, sort),
                  );
                },
              ),
              _buildDivider(context),
              _SettingsTile(
                icon: Icons.cleaning_services_outlined,
                iconBgColor: const Color(0xFFE5F3EA),
                iconColor: const Color(0xFF3D8B5F),
                title: "Clear Document Cache",
                subtitle: "Free temporary render cache ($_cacheSizeStr)",
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5F3EA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "Clear",
                    style: TextStyle(
                      color: Color(0xFF3D8B5F),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                onTap: () => _showClearCacheDialog(context),
              ),
              _buildDivider(context),
              ValueListenableBuilder<bool>(
                valueListenable: _settings.autoCacheCleanupNotifier,
                builder: (context, autoCleanup, _) {
                  return _SettingsSwitchTile(
                    icon: Icons.cached_outlined,
                    iconBgColor: const Color(0xFFE5F3EA),
                    iconColor: const Color(0xFF3D8B5F),
                    title: "Auto Cache Cleanup",
                    subtitle: "Automatically prune cached files on exit",
                    value: autoCleanup,
                    onChanged: (val) => _settings.setAutoCacheCleanup(val),
                  );
                },
              ),
              _buildDivider(context),
              ValueListenableBuilder<bool>(
                valueListenable: _settings.confirmBeforeDeleteNotifier,
                builder: (context, confirmDelete, _) {
                  return _SettingsSwitchTile(
                    icon: Icons.delete_sweep_outlined,
                    iconBgColor: const Color(0xFFE5F3EA),
                    iconColor: const Color(0xFF3D8B5F),
                    title: "Confirm Before Deleting",
                    subtitle: "Prompt confirmation before removing files",
                    value: confirmDelete,
                    onChanged: (val) => _settings.setConfirmBeforeDelete(val),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 20),
          _buildSectionHeader(
            context,
            AppConfig.isAiFeatureEnabled ? "AI Intelligence & Privacy" : "Privacy & Security",
          ),
          _buildCardGroup(
            context,
            children: [
              if (AppConfig.isAiFeatureEnabled) ...[
                ValueListenableBuilder<String>(
                  valueListenable: _settings.aiProviderNotifier,
                  builder: (context, provider, _) {
                    final isGemini = provider == 'gemini';
                    return _SettingsTile(
                      icon: Icons.auto_awesome_rounded,
                      iconBgColor: const Color(0xFFF0E5FC),
                      iconColor: const Color(0xFF7046A8),
                      title: "AI Processing Engine",
                      subtitle: isGemini
                          ? "Google Gemini (Cloud AI)"
                          : "Smart Local NLP (100% Offline & Private)",
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey,
                      ),
                      onTap: () => _showAiEngineDialog(context),
                    );
                  },
                ),
                _buildDivider(context),
              ],
              const _SettingsTile(
                icon: Icons.security_rounded,
                iconBgColor: Color(0xFFE5F3EA),
                iconColor: Color(0xFF3D8B5F),
                title: "Document Privacy",
                subtitle: "On-device processing with zero data uploads by default",
                trailing: Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF3D8B5F),
                  size: 20,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          _buildSectionHeader(context, "Support & Community"),
          _buildCardGroup(
            context,
            children: [
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                iconBgColor: const Color(0xFFF9E9DF),
                iconColor: const Color(0xFFC7653C),
                title: "Help & FAQ",
                subtitle: "Answers to common questions and guide",
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey,
                ),
                onTap: () => _showFaqBottomSheet(context),
              ),
              _buildDivider(context),
              _SettingsTile(
                icon: Icons.star_rate_outlined,
                iconBgColor: const Color(0xFFF9E9DF),
                iconColor: const Color(0xFFC7653C),
                title: "Rate Us & Feedback",
                subtitle: "Tell us what you love or how to improve",
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey,
                ),
                onTap: () => _showRatingDialog(context),
              ),
              _buildDivider(context),
              _SettingsTile(
                icon: Icons.share_outlined,
                iconBgColor: const Color(0xFFF9E9DF),
                iconColor: const Color(0xFFC7653C),
                title: "Share App",
                subtitle: "Recommend All Documents Reader to friends",
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey,
                ),
                onTap: () => _showShareDialog(context),
              ),
            ],
          ),

          const SizedBox(height: 20),
          _buildSectionHeader(context, "About & Legal"),
          _buildCardGroup(
            context,
            children: [
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                iconBgColor: const Color(0xFFE6F0F4),
                iconColor: const Color(0xFF4B8799),
                title: "Privacy Policy",
                subtitle: "Learn how your documents remain private",
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey,
                ),
                onTap: () => _showPrivacyPolicyModal(context),
              ),
              _buildDivider(context),
              _SettingsTile(
                icon: Icons.description_outlined,
                iconBgColor: const Color(0xFFE6F0F4),
                iconColor: const Color(0xFF4B8799),
                title: "Terms of Service",
                subtitle: "Terms and conditions of application usage",
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey,
                ),
                onTap: () => _showTermsModal(context),
              ),
              _buildDivider(context),
              _SettingsTile(
                icon: Icons.code_rounded,
                iconBgColor: const Color(0xFFE6F0F4),
                iconColor: const Color(0xFF4B8799),
                title: "Open Source Licenses",
                subtitle: "Libraries and tools powering the reader",
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey,
                ),
                onTap: () {
                  showLicensePage(
                    context: context,
                    applicationName: "All Documents Reader",
                    applicationVersion: "1.0.0",
                    applicationIcon: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        Icons.description_outlined,
                        size: 40,
                        color: Color(0xFF7046A8),
                      ),
                    ),
                  );
                },
              ),
              _buildDivider(context),
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                iconBgColor: const Color(0xFFE6F0F4),
                iconColor: const Color(0xFF4B8799),
                title: "About App",
                subtitle: "Version 1.0.0 (Build 1)",
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey,
                ),
                onTap: () => _showAboutAppDialog(context),
              ),
            ],
          ),

          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Text(
                  "All Documents Reader",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : const Color(0xFF7046A8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Version 1.0.0 (Build 1) • All Rights Reserved",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // --- Widgets Helpers ---

  Widget _buildAppHeaderCard(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF2C223B), const Color(0xFF1D1824)]
              : [const Color(0xFF7046A8), const Color(0xFF8B5DC7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF7046A8))
                .withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        "All Documents Reader",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Universal PDF, Word, Excel & Image Reader",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    "Offline Mode Active • 100% Private",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFC7B8DF)
              : const Color(0xFF62487E),
        ),
      ),
    );
  }

  Widget _buildCardGroup(
    BuildContext context, {
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF211C29) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF2E2638) : const Color(0xFFEDE5F4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 1,
      indent: 64,
      endIndent: 16,
      color: isDark ? const Color(0xFF2E2738) : const Color(0xFFF1EBF7),
    );
  }

  String _getThemeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return "System Default";
      case ThemeMode.light:
        return "Light Theme";
      case ThemeMode.dark:
        return "Dark Theme";
    }
  }

  String _getSortOrderLabel(String sort) {
    switch (sort) {
      case 'recent':
        return "Recently Modified (Newest first)";
      case 'name':
        return "Alphabetical (A to Z)";
      case 'size':
        return "File Size (Largest first)";
      case 'type':
        return "File Format / Type";
      default:
        return "Recently Modified";
    }
  }

  // --- Dialogs & Modal Handlers ---

  Future<void> _showAiEngineDialog(BuildContext context) async {
    final currentProv = await _settings.getAiProvider();
    final currentKey = await _settings.getGeminiApiKey();
    final keyController = TextEditingController(text: currentKey ?? '');
    String selectedProv = currentProv;

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.tune_rounded, color: Color(0xFF7046A8)),
                  SizedBox(width: 10),
                  Text('AI Engine Settings'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose your preferred AI processing mode:',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => setDialogState(() => selectedProv = 'local'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selectedProv == 'local'
                              ? const Color(0xFF7046A8).withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedProv == 'local'
                                ? const Color(0xFF7046A8)
                                : Colors.grey.withValues(alpha: 0.3),
                            width: selectedProv == 'local' ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selectedProv == 'local'
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: selectedProv == 'local' ? const Color(0xFF7046A8) : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Smart Local NLP (Offline)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    '100% private, on-device, no API key needed',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => setDialogState(() => selectedProv = 'gemini'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selectedProv == 'gemini'
                              ? const Color(0xFF7046A8).withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedProv == 'gemini'
                                ? const Color(0xFF7046A8)
                                : Colors.grey.withValues(alpha: 0.3),
                            width: selectedProv == 'gemini' ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selectedProv == 'gemini'
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: selectedProv == 'gemini' ? const Color(0xFF7046A8) : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Google Gemini (Cloud AI)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    'Bring your own API key for cloud LLM reasoning',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (selectedProv == 'gemini') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: keyController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Gemini API Key',
                          hintText: 'AIzaSy...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          helperText: 'Saved securely on your device. Never shared.',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield_outlined, color: Colors.amber, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Document text is sent to Google Gemini only when Cloud AI is explicitly selected.',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _settings.setAiProvider(selectedProv);
                    await _settings.setGeminiApiKey(keyController.text.trim());
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save Settings'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSelectableDialogOption<T>({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required T value,
    required T groupValue,
    required ValueChanged<T> onSelect,
  }) {
    final isSelected = value == groupValue;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onSelect(value),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? const Color(0xFF382A4A)
                  : const Color(0xFFF1E7FA))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF7046A8)
                : (isDark ? const Color(0xFF332B3D) : const Color(0xFFE8E2EE)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF7046A8)
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 14.5,
                      color: isSelected
                          ? (isDark ? Colors.white : const Color(0xFF7046A8))
                          : (isDark ? Colors.white : const Color(0xFF231F27)),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF7046A8),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _showThemeModeDialog(BuildContext context, ThemeMode currentMode) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.palette_outlined, color: Color(0xFF7046A8)),
              SizedBox(width: 10),
              Text("Choose Theme"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSelectableDialogOption<ThemeMode>(
                context: context,
                title: "System Default",
                subtitle: "Follows device OS theme settings",
                icon: Icons.settings_suggest_outlined,
                value: ThemeMode.system,
                groupValue: currentMode,
                onSelect: (val) {
                  _settings.setThemeMode(val);
                  Navigator.pop(context);
                },
              ),
              _buildSelectableDialogOption<ThemeMode>(
                context: context,
                title: "Light Theme",
                subtitle: "Crisp, clear and bright lavender",
                icon: Icons.wb_sunny_outlined,
                value: ThemeMode.light,
                groupValue: currentMode,
                onSelect: (val) {
                  _settings.setThemeMode(val);
                  Navigator.pop(context);
                },
              ),
              _buildSelectableDialogOption<ThemeMode>(
                context: context,
                title: "Dark Theme",
                subtitle: "Easy on eyes for night reading",
                icon: Icons.nightlight_outlined,
                value: ThemeMode.dark,
                groupValue: currentMode,
                onSelect: (val) {
                  _settings.setThemeMode(val);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  void _showViewModeDialog(BuildContext context, String currentViewMode) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("Default Viewer Mode"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSelectableDialogOption<String>(
                context: context,
                title: "Continuous Vertical Scroll",
                subtitle: "Smooth uninterrupted scrolling",
                icon: Icons.view_headline_rounded,
                value: "vertical",
                groupValue: currentViewMode,
                onSelect: (val) {
                  _settings.setDefaultViewMode(val);
                  Navigator.pop(context);
                },
              ),
              _buildSelectableDialogOption<String>(
                context: context,
                title: "Horizontal Page Flip",
                subtitle: "Book-like swipe pagination",
                icon: Icons.view_carousel_rounded,
                value: "horizontal",
                groupValue: currentViewMode,
                onSelect: (val) {
                  _settings.setDefaultViewMode(val);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  void _showSortOrderDialog(BuildContext context, String currentSort) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("Default Sort Order"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSelectableDialogOption<String>(
                context: context,
                title: "Recently Modified",
                subtitle: "Newest files first",
                icon: Icons.schedule_rounded,
                value: "recent",
                groupValue: currentSort,
                onSelect: (val) {
                  _settings.setDefaultSort(val);
                  Navigator.pop(context);
                },
              ),
              _buildSelectableDialogOption<String>(
                context: context,
                title: "Alphabetical",
                subtitle: "A to Z by file name",
                icon: Icons.sort_by_alpha_rounded,
                value: "name",
                groupValue: currentSort,
                onSelect: (val) {
                  _settings.setDefaultSort(val);
                  Navigator.pop(context);
                },
              ),
              _buildSelectableDialogOption<String>(
                context: context,
                title: "File Size",
                subtitle: "Largest documents first",
                icon: Icons.data_usage_rounded,
                value: "size",
                groupValue: currentSort,
                onSelect: (val) {
                  _settings.setDefaultSort(val);
                  Navigator.pop(context);
                },
              ),
              _buildSelectableDialogOption<String>(
                context: context,
                title: "Document Type",
                subtitle: "Group by PDF, Office, Image",
                icon: Icons.category_rounded,
                value: "type",
                groupValue: currentSort,
                onSelect: (val) {
                  _settings.setDefaultSort(val);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.cleaning_services_outlined, color: Color(0xFF3D8B5F)),
              SizedBox(width: 10),
              Text("Clear Cache"),
            ],
          ),
          content: const Text(
            "This will delete temporary PDF rendering caches and thumbnail buffers. Your original document files will remain completely safe.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3D8B5F),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(context);
                final freedBytes = await _settings.clearCache();
                await _updateCacheSize();
                if (context.mounted) {
                  final freedFormatted = _formatBytes(freedBytes);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(freedBytes > 0
                              ? "Cache cleared! Freed $freedFormatted"
                              : "Cache is already clean."),
                        ],
                      ),
                    ),
                  );
                }
              },
              child: const Text("Clear Now"),
            ),
          ],
        );
      },
    );
  }

  void _showResetDefaultsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("Reset Settings"),
          content: const Text(
            "Are you sure you want to reset all preferences, theme choices, and reading modes back to original defaults?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7046A8),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(context);
                await _settings.resetAllSettings();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      content: const Text("Settings restored to defaults."),
                    ),
                  );
                }
              },
              child: const Text("Reset"),
            ),
          ],
        );
      },
    );
  }

  void _showFaqBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(
                        Icons.help_outline_rounded,
                        color: Color(0xFF7046A8),
                        size: 26,
                      ),
                      SizedBox(width: 10),
                      Text(
                        "Help & FAQ",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildFaqItem(
                    isDark,
                    "What document formats are supported?",
                    "All Documents Reader supports PDF (.pdf), Microsoft Word (.doc, .docx), Excel spreadsheets (.xls, .xlsx), PowerPoint presentations (.ppt, .pptx), Plain Text (.txt), and image formats (.jpg, .jpeg, .png).",
                  ),
                  _buildFaqItem(
                    isDark,
                    "How do I add or import new documents?",
                    "Go to the 'Documents' tab from the bottom navigation bar and tap the '+' floating action button in the bottom right corner. Select whether you are picking a PDF, Office document, or Image.",
                  ),
                  _buildFaqItem(
                    isDark,
                    "Are my documents uploaded to any server?",
                    "No! Your privacy is 100% guaranteed. All documents are processed, opened, and rendered entirely locally on your device. We do not store, transmit, or inspect your personal files.",
                  ),
                  _buildFaqItem(
                    isDark,
                    "How do I zoom in on documents and images?",
                    "In PDF files and images, you can pinch-to-zoom with two fingers or double-tap on any area to zoom in and out smoothly.",
                  ),
                  _buildFaqItem(
                    isDark,
                    "How do I delete or remove a document from my list?",
                    "In the Documents tab, tap the three-dots (⋮) menu icon on any document card and choose 'Delete' to remove the document reference.",
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Got it!"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFaqItem(bool isDark, String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF282231) : const Color(0xFFF7F3FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: const Color(0xFF7046A8),
          collapsedIconColor: Colors.grey,
          title: Text(
            question,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14.5,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 16,
              ),
              child: Text(
                answer,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: isDark ? Colors.grey[300] : const Color(0xFF554E5C),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRatingDialog(BuildContext context) {
    int selectedRating = 5;
    final TextEditingController feedbackCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Column(
                children: [
                  Icon(Icons.stars_rounded, color: Colors.amber, size: 48),
                  SizedBox(height: 8),
                  Text(
                    "Rate Your Experience",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Enjoying All Documents Reader?",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starIndex = index + 1;
                      return IconButton(
                        iconSize: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        icon: Icon(
                          starIndex <= selectedRating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: Colors.amber,
                        ),
                        onPressed: () {
                          setModalState(() {
                            selectedRating = starIndex;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: feedbackCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: "Tell us what you like or how to improve...",
                      hintStyle: const TextStyle(fontSize: 13),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Not Now"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        content: const Text(
                          "Thank you so much for your feedback! ⭐",
                        ),
                      ),
                    );
                  },
                  child: const Text("Submit"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showShareDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              const Icon(
                Icons.share_rounded,
                size: 38,
                color: Color(0xFF7046A8),
              ),
              const SizedBox(height: 10),
              const Text(
                "Share All Documents Reader",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                "Spread the word about the fastest and cleanest document reader app.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8DEF8),
                  child: Icon(Icons.copy_rounded, color: Color(0xFF7046A8)),
                ),
                title: const Text("Copy Download Link"),
                subtitle: const Text(
                  "https://github.com/Nidafatima0610/Document-reader",
                ),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      content: const Text("Link copied to clipboard!"),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showPrivacyPolicyModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(
                        Icons.privacy_tip_outlined,
                        color: Color(0xFF4B8799),
                        size: 26,
                      ),
                      SizedBox(width: 10),
                      Text(
                        "Privacy Policy",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Last updated: September 2026\n\n"
                    "1. Local Processing Only\n"
                    "All Documents Reader is engineered with security and user privacy as top priorities. All documents (PDFs, Word files, Excel spreadsheets, presentations, and images) are parsed, rendered, and stored strictly on your local device.\n\n"
                    "2. No Cloud Transmission\n"
                    "The app does not transmit file contents, metadata, or reading history to any third-party servers or analytics pipelines.\n\n"
                    "3. Device Storage Permissions\n"
                    "Storage permissions are only requested to allow you to select, open, and view files chosen directly by you.\n\n"
                    "4. Contact & Inquiries\n"
                    "For inquiries regarding privacy, please visit our open-source repository.",
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Close"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showTermsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        color: Color(0xFF4B8799),
                        size: 26,
                      ),
                      SizedBox(width: 10),
                      Text(
                        "Terms of Service",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Welcome to All Documents Reader.\n\n"
                    "1. Permitted Use\n"
                    "This application is provided for viewing and managing documents on compatible mobile and desktop platforms.\n\n"
                    "2. User Responsibility\n"
                    "You are responsible for ensuring you have lawful access to any documents and media opened using this reader.\n\n"
                    "3. Disclaimer of Warranty\n"
                    "The software is provided 'as is', without warranty of any kind, express or implied. In no event shall the authors be liable for any claim or damages.",
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("I Understand"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAboutAppDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8DEF8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  size: 44,
                  color: Color(0xFF7046A8),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                "All Documents Reader",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                "Version 1.0.0 (Build 1)",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              const Text(
                "A fast, modern, and beautiful document viewer for PDF, Office, Text and Image documents built with Flutter.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Done"),
            ),
          ],
        );
      },
    );
  }
}

// --- Helper Tile Widgets ---

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color:
                      isDark ? iconColor.withValues(alpha: 0.2) : iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF231F27),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color:
                            isDark ? Colors.grey[400] : const Color(0xFF6E6877),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color:
                  isDark ? iconColor.withValues(alpha: 0.2) : iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF231F27),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    color:
                        isDark ? Colors.grey[400] : const Color(0xFF6E6877),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeTrackColor: AppTheme.primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
