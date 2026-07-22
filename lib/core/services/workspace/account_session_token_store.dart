import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:kelivo_secure_core/kelivo_secure_core.dart';
import 'package:path/path.dart' as p;

import '../backup/restore_durability.dart';

final class AccountSessionTokenReference {
  factory AccountSessionTokenReference({
    required int generation,
    required String slot,
  }) {
    if (generation <= 0 || generation > _maxGeneration) {
      throw const FormatException('account_session_token_generation');
    }
    if (slot != 'a' && slot != 'b') {
      throw const FormatException('account_session_token_slot');
    }
    return AccountSessionTokenReference._(generation: generation, slot: slot);
  }

  const AccountSessionTokenReference._({
    required this.generation,
    required this.slot,
  });

  static const formatVersion = 1;
  static const _maxGeneration = 0x7fffffffffffffff;

  final int generation;
  final String slot;

  static AccountSessionTokenReference next(
    AccountSessionTokenReference? current,
  ) {
    final generation = (current?.generation ?? 0) + 1;
    return AccountSessionTokenReference(
      generation: generation,
      slot: current?.slot == 'a' ? 'b' : 'a',
    );
  }

  Map<String, Object> toJson() => <String, Object>{
    'version': formatVersion,
    'generation': generation,
    'slot': slot,
  };

  factory AccountSessionTokenReference.fromJson(Object? value) {
    if (value is! Map<String, Object?> ||
        value.length != 3 ||
        value['version'] != formatVersion ||
        value['generation'] is! int ||
        value['slot'] is! String) {
      throw const FormatException('account_session_token_reference');
    }
    return AccountSessionTokenReference(
      generation: value['generation'] as int,
      slot: value['slot'] as String,
    );
  }
}

abstract interface class AccountSessionTokenStore {
  Future<AccountSessionTokenReference> writeToken({
    required Directory accountDirectory,
    required String workspaceKey,
    required String token,
    required AccountSessionTokenReference? currentReference,
    required RestoreDurability durability,
  });

  Future<String> readToken({
    required Directory accountDirectory,
    required String workspaceKey,
    required AccountSessionTokenReference reference,
  });

  Future<void> deleteTokens({
    required Directory accountDirectory,
    required AccountSessionTokenReference? keep,
    required RestoreDurability durability,
  });
}

final class SecureAccountSessionTokenStore implements AccountSessionTokenStore {
  const SecureAccountSessionTokenStore();

  static final RegExp _workspaceKeyPattern = RegExp(r'^[0-9a-f]{64}$');
  static final Uint8List _frameMagic = Uint8List.fromList(
    ascii.encode('KELVTK01'),
  );
  static const _frameHeaderLength = 20;
  static const _maximumTokenBytes = 64 * 1024;
  static const _maximumEnvelopeBytes = _maximumTokenBytes + 80;
  static const _recordEpoch = 1;
  static const _slotDomain = 'kelivo.account.session.slot.v1';
  static const _recordDomain = 'kelivo.account.session.record.v1';
  static const _aadDomain = 'kelivo.account.session.aad.v1';
  static const _recordName = 'token-v1';

  final KelivoSecureCore _secureCore = const KelivoSecureCore();

  @override
  Future<AccountSessionTokenReference> writeToken({
    required Directory accountDirectory,
    required String workspaceKey,
    required String token,
    required AccountSessionTokenReference? currentReference,
    required RestoreDurability durability,
  }) async {
    _validateWorkspaceKey(workspaceKey);
    final plaintext = Uint8List.fromList(utf8.encode(token));
    if (plaintext.isEmpty || plaintext.length > _maximumTokenBytes) {
      plaintext.fillRange(0, plaintext.length, 0);
      throw const FormatException('account_session_token_length');
    }

    final reference = AccountSessionTokenReference.next(currentReference);
    try {
      final envelope = await _withKeyHandle(
        workspaceKey,
        (handle) => _secureCore.sealRecord(
          handle,
          recordId: _deriveIdentifier(_recordDomain, workspaceKey),
          epoch: _recordEpoch,
          associatedData: _associatedData(workspaceKey, reference),
          plaintext: plaintext,
        ),
      );
      await _writeFrame(
        accountDirectory: accountDirectory,
        reference: reference,
        envelope: envelope,
        durability: durability,
      );
      return reference;
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }

  @override
  Future<String> readToken({
    required Directory accountDirectory,
    required String workspaceKey,
    required AccountSessionTokenReference reference,
  }) async {
    _validateWorkspaceKey(workspaceKey);
    final envelope = await _readFrame(
      accountDirectory: accountDirectory,
      reference: reference,
    );
    final plaintext = await _withKeyHandle(
      workspaceKey,
      (handle) => _secureCore.openRecord(
        handle,
        recordId: _deriveIdentifier(_recordDomain, workspaceKey),
        epoch: _recordEpoch,
        associatedData: _associatedData(workspaceKey, reference),
        envelope: envelope,
      ),
      createMissing: false,
    );
    try {
      if (plaintext.isEmpty || plaintext.length > _maximumTokenBytes) {
        throw const FormatException('account_session_token_length');
      }
      return utf8.decode(plaintext, allowMalformed: false);
    } on FormatException {
      throw const FormatException('account_session_token_encoding');
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }

  @override
  Future<void> deleteTokens({
    required Directory accountDirectory,
    required AccountSessionTokenReference? keep,
    required RestoreDurability durability,
  }) async {
    var deleted = false;
    for (final slot in const <String>['a', 'b']) {
      if (keep?.slot != slot) {
        deleted =
            await _deleteRegularFile(_targetFile(accountDirectory, slot)) ||
            deleted;
      }
      deleted =
          await _deleteRegularFile(_temporaryFile(accountDirectory, slot)) ||
          deleted;
    }
    if (deleted) {
      await durability.syncDirectory(accountDirectory, fullBarrier: true);
    }
  }

  Future<T> _withKeyHandle<T>(
    String workspaceKey,
    Future<T> Function(KelivoKeyHandle handle) action, {
    bool createMissing = true,
  }) async {
    final slotId = _deriveIdentifier(_slotDomain, workspaceKey);
    final handle = createMissing
        ? await _openOrCreateSlot(slotId)
        : await _secureCore.openSlot(slotId);

    var closeAttempted = false;
    try {
      final result = await action(handle);
      closeAttempted = true;
      await _secureCore.close(handle);
      return result;
    } catch (error, stackTrace) {
      if (!closeAttempted) {
        try {
          await _secureCore.close(handle);
        } catch (closeError, closeStackTrace) {
          Error.throwWithStackTrace(
            StateError(
              'account_session_token_key_close_after_failure:'
              '$error;$closeError',
            ),
            closeStackTrace,
          );
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<KelivoKeyHandle> _openOrCreateSlot(Uint8List slotId) async {
    try {
      return await _secureCore.createSlot(slotId);
    } on KelivoSecureCoreException catch (error) {
      if (error.status != KelivoSecureCoreStatus.slotAlreadyExists) rethrow;
      return _secureCore.openSlot(slotId);
    }
  }

  static Future<void> _writeFrame({
    required Directory accountDirectory,
    required AccountSessionTokenReference reference,
    required Uint8List envelope,
    required RestoreDurability durability,
  }) async {
    if (envelope.isEmpty || envelope.length > _maximumEnvelopeBytes) {
      throw const FormatException('account_session_token_envelope_length');
    }
    final frame = Uint8List(_frameHeaderLength + envelope.length);
    frame.setRange(0, _frameMagic.length, _frameMagic);
    final fields = ByteData.sublistView(frame);
    fields.setUint64(8, reference.generation, Endian.big);
    fields.setUint32(16, envelope.length, Endian.big);
    frame.setRange(_frameHeaderLength, frame.length, envelope);

    final target = _targetFile(accountDirectory, reference.slot);
    final temporary = _temporaryFile(accountDirectory, reference.slot);
    await _prepareTemporaryFile(temporary);
    await temporary.writeAsBytes(frame, flush: true);
    await durability.restrictFile(temporary);
    await durability.syncFile(temporary, fullBarrier: true);

    final targetType = await FileSystemEntity.type(
      target.path,
      followLinks: false,
    );
    if (targetType != FileSystemEntityType.notFound) {
      if (targetType != FileSystemEntityType.file) {
        throw StateError('account_session_token_target');
      }
      await target.delete();
      await durability.syncDirectory(accountDirectory, fullBarrier: true);
    }
    await durability.renameAndSync(source: temporary, targetPath: target.path);
  }

  static Future<Uint8List> _readFrame({
    required Directory accountDirectory,
    required AccountSessionTokenReference reference,
  }) async {
    final file = _targetFile(accountDirectory, reference.slot);
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      throw StateError('account_session_token_missing');
    }
    if (type != FileSystemEntityType.file) {
      throw const FormatException('account_session_token_frame');
    }

    final reader = await file.open(mode: FileMode.read);
    try {
      final length = await reader.length();
      if (length <= _frameHeaderLength ||
          length > _frameHeaderLength + _maximumEnvelopeBytes) {
        throw const FormatException('account_session_token_frame');
      }
      final frame = await reader.read(length);
      if (frame.length != length || !_hasFrameMagic(frame)) {
        throw const FormatException('account_session_token_frame');
      }
      final fields = ByteData.sublistView(frame);
      final generation = fields.getUint64(8, Endian.big);
      final envelopeLength = fields.getUint32(16, Endian.big);
      if (generation != reference.generation ||
          envelopeLength == 0 ||
          envelopeLength > _maximumEnvelopeBytes ||
          _frameHeaderLength + envelopeLength != frame.length) {
        throw const FormatException('account_session_token_frame');
      }
      return Uint8List.fromList(frame.sublist(_frameHeaderLength));
    } finally {
      await reader.close();
    }
  }

  static Future<void> _prepareTemporaryFile(File file) async {
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.file) {
      throw StateError('account_session_token_temporary');
    }
    await file.delete();
  }

  static Future<bool> _deleteRegularFile(File file) async {
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return false;
    if (type != FileSystemEntityType.file) {
      throw StateError('account_session_token_delete_target');
    }
    await file.delete();
    return true;
  }

  static bool _hasFrameMagic(Uint8List frame) {
    if (frame.length < _frameMagic.length) return false;
    for (var index = 0; index < _frameMagic.length; index++) {
      if (frame[index] != _frameMagic[index]) return false;
    }
    return true;
  }

  static Uint8List _deriveIdentifier(String domain, String workspaceKey) {
    final digest = sha256.convert(utf8.encode('$domain\u0000$workspaceKey'));
    return Uint8List.fromList(digest.bytes.take(16).toList(growable: false));
  }

  static Uint8List _associatedData(
    String workspaceKey,
    AccountSessionTokenReference reference,
  ) {
    return Uint8List.fromList(
      utf8.encode(
        '$_aadDomain\n$workspaceKey\n${reference.slot}\n${reference.generation}',
      ),
    );
  }

  static File _targetFile(Directory directory, String slot) {
    return File(p.join(directory.path, '$_recordName-$slot.bin'));
  }

  static File _temporaryFile(Directory directory, String slot) {
    return File(p.join(directory.path, '.$_recordName-$slot.next'));
  }

  static void _validateWorkspaceKey(String workspaceKey) {
    if (!_workspaceKeyPattern.hasMatch(workspaceKey)) {
      throw const FormatException('account_session_token_workspace');
    }
  }
}
