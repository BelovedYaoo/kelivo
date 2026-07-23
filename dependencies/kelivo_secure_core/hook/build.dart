import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

const _assetName = 'kelivo_secure_core_bindings_generated.dart';

void main(List<String> arguments) async {
  await build(arguments, (input, output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }

    final code = input.config.code;
    if (code.linkModePreference == LinkModePreference.static) {
      throw BuildError(message: 'Kelivo 安全核心不支持静态链接请求。');
    }

    final target = _resolveTarget(code);
    final nativeRoot = input.packageRoot.resolve('native/');
    final protocolRoot = input.packageRoot.resolve('protocol/');
    final dependencies = _nativeDependencies(nativeRoot, protocolRoot);
    output.dependencies.addAll(dependencies);

    final outputDirectory = Directory.fromUri(input.outputDirectory);
    await outputDirectory.create(recursive: true);
    final cargoTargetDirectory = input.outputDirectory.resolve('cargo-target/');
    await Directory.fromUri(cargoTargetDirectory).create(recursive: true);

    final cargoArguments = <String>[
      'build',
      '--locked',
      '--release',
      '--target',
      target.rustTriple,
      '--target-dir',
      cargoTargetDirectory.toFilePath(),
    ];
    final cargoResult = await Process.run(
      'cargo',
      cargoArguments,
      workingDirectory: nativeRoot.toFilePath(),
      environment: _cargoEnvironment(code, target),
    );
    final cargoStdout = cargoResult.stdout.toString();
    final cargoStderr = cargoResult.stderr.toString();
    if (cargoStdout.isNotEmpty) {
      stdout.write(cargoStdout);
    }
    if (cargoStderr.isNotEmpty) {
      stderr.write(cargoStderr);
    }
    if (cargoResult.exitCode != 0) {
      throw BuildError(
        message: 'Kelivo 安全核心 Cargo 构建失败，退出码 ${cargoResult.exitCode}。',
      );
    }

    final builtLibrary = cargoTargetDirectory.resolve(
      '${target.rustTriple}/release/${target.libraryFileName}',
    );
    final builtFile = File.fromUri(builtLibrary);
    if (!await builtFile.exists()) {
      throw BuildError(
        message: 'Cargo 构建未生成预期动态库：${builtLibrary.toFilePath()}',
      );
    }

    final assetPath = input.outputDirectory.resolve(target.libraryFileName);
    await builtFile.copy(assetPath.toFilePath());
    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: _assetName,
        file: assetPath,
        linkMode: DynamicLoadingBundled(),
      ),
    );
  });
}

_CargoTarget _resolveTarget(CodeConfig code) {
  final os = code.targetOS;
  final architecture = code.targetArchitecture;

  if (os == OS.windows && architecture == Architecture.x64) {
    return const _CargoTarget(
      rustTriple: 'x86_64-pc-windows-msvc',
      libraryFileName: 'kelivo_secure_core.dll',
    );
  }
  if (os == OS.android && architecture == Architecture.arm) {
    return const _CargoTarget(
      rustTriple: 'armv7-linux-androideabi',
      libraryFileName: 'libkelivo_secure_core.so',
      androidClangPrefix: 'armv7a-linux-androideabi',
    );
  }
  if (os == OS.android && architecture == Architecture.arm64) {
    return const _CargoTarget(
      rustTriple: 'aarch64-linux-android',
      libraryFileName: 'libkelivo_secure_core.so',
      androidClangPrefix: 'aarch64-linux-android',
    );
  }
  if (os == OS.android && architecture == Architecture.x64) {
    return const _CargoTarget(
      rustTriple: 'x86_64-linux-android',
      libraryFileName: 'libkelivo_secure_core.so',
      androidClangPrefix: 'x86_64-linux-android',
    );
  }
  if (os == OS.linux && architecture == Architecture.x64) {
    return const _CargoTarget(
      rustTriple: 'x86_64-unknown-linux-gnu',
      libraryFileName: 'libkelivo_secure_core.so',
    );
  }
  if (os == OS.linux && architecture == Architecture.arm64) {
    return const _CargoTarget(
      rustTriple: 'aarch64-unknown-linux-gnu',
      libraryFileName: 'libkelivo_secure_core.so',
    );
  }

  throw BuildError(
    message: 'Kelivo 安全核心不支持目标 ${os.name}/${architecture.name}。',
  );
}

Map<String, String> _cargoEnvironment(CodeConfig code, _CargoTarget target) {
  final compiler = code.cCompiler;
  if (compiler == null) {
    throw BuildError(
      message:
          '目标 ${code.targetOS.name}/${code.targetArchitecture.name} 缺少 C 工具链。',
    );
  }

  final String cargoLinker;
  final String cCompiler;
  if (code.targetOS == OS.android) {
    final apiLevel = code.android.targetNdkApi;
    if (apiLevel <= 0) {
      throw BuildError(message: 'Android NDK API 必须为正整数。');
    }
    final clangPrefix = target.androidClangPrefix;
    if (clangPrefix == null) {
      throw BuildError(message: 'Android 目标缺少 Clang 前缀。');
    }

    // Rust 与其 C 依赖必须共享带 API 级别的 NDK 包装器，避免误连宿主 libc。
    final compilerDirectory = File.fromUri(compiler.compiler).parent.uri;
    final wrapperSuffix = Platform.isWindows ? '.cmd' : '';
    final wrapper = compilerDirectory.resolve(
      '$clangPrefix$apiLevel-clang$wrapperSuffix',
    );
    if (!File.fromUri(wrapper).existsSync()) {
      throw BuildError(
        message: '未找到 Android NDK Clang 包装器：${wrapper.toFilePath()}',
      );
    }
    cargoLinker = wrapper.toFilePath();
    cCompiler = cargoLinker;
  } else {
    cargoLinker = code.targetOS == OS.windows
        ? compiler.linker.toFilePath()
        : compiler.compiler.toFilePath();
    cCompiler = compiler.compiler.toFilePath();
  }

  final rustTargetKey = target.rustTriple.toUpperCase().replaceAll('-', '_');
  final ccTargetKey = target.rustTriple.replaceAll('-', '_');
  final archiver = compiler.archiver.toFilePath();

  final environment = <String, String>{
    'CARGO_TARGET_${rustTargetKey}_LINKER': cargoLinker,
    'CC_${target.rustTriple}': cCompiler,
    'CC_$ccTargetKey': cCompiler,
    'AR_${target.rustTriple}': archiver,
    'AR_$ccTargetKey': archiver,
  };
  if (code.targetOS == OS.android) {
    // 不同 Android 架构的 NDK 默认页大小并不一致，统一约束才能避免 16 KiB 设备拒绝加载。
    environment['CARGO_TARGET_${rustTargetKey}_RUSTFLAGS'] =
        '-C link-arg=-Wl,-z,max-page-size=16384';
  }
  return environment;
}

List<Uri> _nativeDependencies(Uri nativeRoot, Uri protocolRoot) {
  final requiredFiles = <Uri>[
    nativeRoot.resolve('Cargo.toml'),
    nativeRoot.resolve('Cargo.lock'),
    nativeRoot.resolve('rust-toolchain.toml'),
    protocolRoot.resolve('Cargo.toml'),
    protocolRoot.resolve('Cargo.lock'),
    protocolRoot.resolve('rust-toolchain.toml'),
  ];
  for (final dependency in requiredFiles) {
    if (!File.fromUri(dependency).existsSync()) {
      throw BuildError(message: '缺少原生构建依赖：${dependency.toFilePath()}');
    }
  }

  final dependencies = <Uri>[...requiredFiles];
  for (final directoryName in const ['src/', 'include/']) {
    final directory = Directory.fromUri(nativeRoot.resolve(directoryName));
    if (!directory.existsSync()) {
      throw BuildError(message: '缺少原生源码目录：${directory.path}');
    }
    dependencies.add(directory.uri);
    final files =
        directory
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .map((file) => file.uri)
            .toList()
          ..sort((left, right) => left.toString().compareTo(right.toString()));
    dependencies.addAll(files);
  }
  final protocolSource = Directory.fromUri(protocolRoot.resolve('src/'));
  if (!protocolSource.existsSync()) {
    throw BuildError(message: '缺少 OPAQUE 协议源码目录：${protocolSource.path}');
  }
  dependencies.add(protocolSource.uri);
  final protocolFiles =
      protocolSource
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .map((file) => file.uri)
          .toList()
        ..sort((left, right) => left.toString().compareTo(right.toString()));
  dependencies.addAll(protocolFiles);
  return dependencies;
}

final class _CargoTarget {
  const _CargoTarget({
    required this.rustTriple,
    required this.libraryFileName,
    this.androidClangPrefix,
  });

  final String rustTriple;
  final String libraryFileName;
  final String? androidClangPrefix;
}
