import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';

class QrScanPage extends StatelessWidget {
  const QrScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _QrScannerPage<String>(decoder: _decodeTextBarcode);
  }
}

class BinaryQrScanPage extends StatelessWidget {
  const BinaryQrScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _QrScannerPage<Uint8List>(decoder: _decodeBinaryBarcode);
  }
}

typedef _QrDecoder<T> = T? Function(Barcode barcode);

class _QrScannerPage<T> extends StatefulWidget {
  const _QrScannerPage({required this.decoder});

  final _QrDecoder<T> decoder;

  @override
  State<_QrScannerPage<T>> createState() => _QrScannerPageState<T>();
}

class _QrScannerPageState<T> extends State<_QrScannerPage<T>> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leading: IosIconButton(
          icon: Lucide.ArrowLeft,
          semanticLabel: l10n.settingsPageBackButton,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.qrScanPageTitle),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_handled) return;
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final value = widget.decoder(barcode);
                if (value != null) {
                  _handled = true;
                  Navigator.of(context).pop<T>(value);
                  break;
                }
              }
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 20,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.qrScanPageInstruction,
                  style: TextStyle(color: cs.onSurface),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String? _decodeTextBarcode(Barcode barcode) {
  final value = barcode.rawValue;
  return value == null || value.isEmpty ? null : value;
}

Uint8List? _decodeBinaryBarcode(Barcode barcode) {
  final decoded = barcode.rawDecodedBytes;
  Uint8List? bytes;
  if (decoded is DecodedBarcodeBytes) {
    bytes = decoded.bytes;
  } else if (decoded is DecodedVisionBarcodeBytes) {
    bytes = decoded.bytes;
  }
  if (bytes == null || bytes.isEmpty) return null;
  return Uint8List.fromList(bytes);
}
