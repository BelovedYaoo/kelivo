import '../models/chat_message.dart';

final class ParsedRemoteInlineImages {
  const ParsedRemoteInlineImages({
    required this.text,
    required this.imageSources,
  });

  final String text;
  final List<String> imageSources;
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
