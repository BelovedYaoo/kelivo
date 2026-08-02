import '../models/chat_message.dart';

final class ParsedRemoteInlineImages {
  const ParsedRemoteInlineImages({
    required this.text,
    required this.imageSources,
  });

  final String text;
  final List<String> imageSources;
}

final class ParsedLocalMarkdownImages {
  const ParsedLocalMarkdownImages({
    required this.content,
    required this.imagePaths,
  });

  final String content;
  final List<String> imagePaths;
}

ParsedLocalMarkdownImages parseLocalMarkdownImages(String raw) {
  final imagePattern = RegExp(
    r'!\[[^\]\r\n]*\]\(([^)\r\n]+)\)',
    multiLine: true,
  );
  final imagePaths = <String>[];
  final content = StringBuffer();
  var cursor = 0;

  for (final match in imagePattern.allMatches(raw)) {
    final source = match.group(1)?.trim() ?? '';
    if (!_isAbsoluteLocalImageSource(source)) continue;
    content.write(raw.substring(cursor, match.start));
    imagePaths.add(source);
    cursor = match.end;
  }
  if (imagePaths.isEmpty) {
    return ParsedLocalMarkdownImages(
      content: raw,
      imagePaths: const <String>[],
    );
  }
  content.write(raw.substring(cursor));
  return ParsedLocalMarkdownImages(
    content: content.toString().trim(),
    imagePaths: List<String>.unmodifiable(imagePaths),
  );
}

bool _isAbsoluteLocalImageSource(String source) {
  if (source.isEmpty ||
      source.contains('\u0000') ||
      isRemoteInlineImageSource(source)) {
    return false;
  }
  return source.startsWith('/') ||
      source.startsWith(r'\\') ||
      RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(source) ||
      source.startsWith('file:');
}

ParsedRemoteInlineImages parseRemoteInlineImages(String raw) {
  final imagePattern = RegExp(r'\[image:([^\]]+)\]');
  final images = <String>[];
  final text = StringBuffer();
  var index = 0;

  while (index < raw.length) {
    final match = imagePattern.matchAsPrefix(raw, index);
    if (match == null) {
      text.write(raw[index]);
      index += 1;
      continue;
    }

    final source = match.group(1)?.trim() ?? '';
    if (!isRemoteInlineImageSource(source)) {
      text.write(match.group(0));
      index = match.end;
      continue;
    }

    images.add(source);
    index = match.end;
  }

  return ParsedRemoteInlineImages(
    text: text.toString().trim(),
    imageSources: List<String>.unmodifiable(images),
  );
}

String chatMessageAttachmentDisplayName(ChatMessageAttachment attachment) {
  final displayName = attachment.displayName?.trim();
  if (displayName?.isNotEmpty == true) return displayName!;

  final normalizedPath = attachment.path.replaceAll('\\', '/');
  final separatorIndex = normalizedPath.lastIndexOf('/');
  return separatorIndex < 0
      ? normalizedPath
      : normalizedPath.substring(separatorIndex + 1);
}

String chatMessageReadablePreview(ChatMessage message) {
  final parsed = parseRemoteInlineImages(message.content);
  final parts = <String>[
    if (parsed.text.isNotEmpty) parsed.text,
    for (final attachment in message.attachments)
      chatMessageAttachmentDisplayName(attachment),
  ];
  return parts.where((part) => part.isNotEmpty).join(' ');
}

bool isRemoteInlineImageSource(String source) {
  return source.startsWith('http://') ||
      source.startsWith('https://') ||
      source.startsWith('data:image/');
}
