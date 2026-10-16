import 'package:flutter/material.dart';
import '../../../data/repositories/settings_repository.dart';

/// Provider managing first-run onboarding and Privacy Policy / Offline Terms agreement.
class OnboardingProvider extends ChangeNotifier {
  final SettingsRepository _settingsRepo;
  bool _isPolicyAccepted = false;
  bool _isLoading = true;

  OnboardingProvider({SettingsRepository? settingsRepo})
      : _settingsRepo = settingsRepo ?? SettingsRepository() {
    _loadPolicyStatus();
  }

  bool get isPolicyAccepted => _isPolicyAccepted;
  bool get isLoading => _isLoading;

  Future<void> _loadPolicyStatus() async {
    try {
      final value = await _settingsRepo.getSetting('policy_accepted');
      _isPolicyAccepted = value == 'true';
    } catch (_) {
      // Memory fallback
      _isPolicyAccepted = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Called when store owner agrees to Privacy Policy and Offline Disclosures
  Future<void> acceptPolicy() async {
    _isPolicyAccepted = true;
    notifyListeners();
    try {
      await _settingsRepo.setSetting('policy_accepted', 'true');
    } catch (_) {}
  }

  /// Resets policy acceptance (used for testing or re-verifying policy in settings)
  Future<void> resetPolicy() async {
    _isPolicyAccepted = false;
    notifyListeners();
    try {
      await _settingsRepo.setSetting('policy_accepted', 'false');
    } catch (_) {}
  }
}
