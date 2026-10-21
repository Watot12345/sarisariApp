import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/localization/language_provider.dart';
import '../../core/strings.dart';
import '../../core/theme/app_theme.dart';

/// Reusable Barcode Scanner modal bottom sheet with live camera viewfinder,
/// flashlight/torch toggle, and manual barcode input fallback.
class BarcodeScannerSheet extends StatefulWidget {
  final String title;

  const BarcodeScannerSheet({
    super.key,
    this.title = AppStrings.scanBarcode,
  });

  static Future<String?> show(
    BuildContext context, {
    String title = AppStrings.scanBarcode,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BarcodeScannerSheet(title: title),
    );
  }

  @override
  State<BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<BarcodeScannerSheet> {
  final TextEditingController _manualCtrl = TextEditingController();
  MobileScannerController? _scannerController;
  bool _isTorchOn = false;
  bool _hasPopped = false;
  String? _inputError;

  static bool get _supportsLiveCamera {
    if (kIsWeb) return false;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    if (_supportsLiveCamera) {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
    }
  }

  @override
  void dispose() {
    _manualCtrl.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  void _toggleTorch() {
    HapticFeedback.selectionClick();
    setState(() {
      _isTorchOn = !_isTorchOn;
    });
    _scannerController?.toggleTorch();
  }

  void _submitBarcode(String rawCode) {
    if (_hasPopped) return;
    final clean = rawCode.trim();
    if (clean.isEmpty) {
      final isTl = context.read<LanguageProvider?>()?.isTagalog ?? false;
      setState(() {
        _inputError = isTl ? 'Mangyaring maglagay o mag-scan ng wastong barcode' : 'Please enter or scan a valid barcode';
      });
      return;
    }
    _hasPopped = true;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(clean);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final langProv = context.watch<LanguageProvider?>();
    final isTl = langProv?.isTagalog ?? false;

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppConstants.borderRadiusTopSheet,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header Row with Flashlight Toggle & Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    key: const Key('scanner_torch_toggle_btn'),
                    tooltip: _isTorchOn
                        ? (isTl ? 'Patayin ang Flashlight' : 'Turn Off Flashlight')
                        : (isTl ? 'Buksan ang Flashlight' : 'Turn On Flashlight'),
                    icon: Icon(
                      _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      color: _isTorchOn ? AppTheme.accentAmber : null,
                    ),
                    onPressed: _toggleTorch,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Camera Viewfinder Box
              Container(
                height: 200,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _isTorchOn
                        ? AppTheme.accentAmber
                        : AppTheme.primaryGreen.withOpacity(0.6),
                    width: 2,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_supportsLiveCamera && _scannerController != null)
                      MobileScanner(
                        controller: _scannerController!,
                        errorBuilder: (context, error, child) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.no_photography_rounded,
                                    color: Colors.orangeAccent,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    error.errorCode == MobileScannerErrorCode.permissionDenied
                                        ? (isTl
                                            ? 'Kailangan ang pahintulot sa camera para makapag-scan ng barcode.\nMagbigay ng pahintulot sa Settings, o gamitin ang manual entry sa ibaba.'
                                            : 'Camera permission is required to scan barcodes.\nPlease grant permission in App Settings, or use manual entry below.')
                                        : (isTl
                                            ? 'Hindi magamit ang camera preview.\nGamitin ang manual entry ng barcode sa ibaba.'
                                            : 'Camera preview unavailable.\nPlease use manual barcode entry below.'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        onDetect: (capture) {
                          for (final barcode in capture.barcodes) {
                            final val = barcode.rawValue;
                            if (val != null && val.trim().isNotEmpty) {
                              _submitBarcode(val);
                              break;
                            }
                          }
                        },
                      )
                    else
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 56,
                            color: _isTorchOn
                                ? AppTheme.accentAmber
                                : AppTheme.primaryGreen,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isTorchOn
                                ? (isTl ? 'Bukas ang Flashlight • Itapat ang barcode sa frame' : 'Flashlight ON • Align barcode in frame')
                                : (isTl ? 'Itapat ang barcode ng paninda sa loob ng frame' : 'Align product barcode inside frame'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                    // Target Reticle Overlay
                    IgnorePointer(
                      child: Container(
                        width: 200,
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withOpacity(0.45),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Manual Entry Fallback Section
              Text(
                isTl ? 'O ilagay ang barcode mano-mano:' : 'Or enter barcode manually:',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('manual_barcode_input'),
                      controller: _manualCtrl,
                      keyboardType: TextInputType.number,
                      onSubmitted: _submitBarcode,
                      onChanged: (_) {
                        if (_inputError != null) {
                          setState(() => _inputError = null);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'e.g. 4800016644023',
                        prefixIcon: const Icon(Icons.keyboard_alt_outlined),
                        errorText: _inputError,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      key: const Key('submit_manual_barcode_btn'),
                      onPressed: () => _submitBarcode(_manualCtrl.text),
                      child: Text(isTl ? 'Gamitin' : 'Use Code'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
