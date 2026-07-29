import 'package:flutter/material.dart';

import '../../features/backup/pages/backup_page.dart';

class DesktopBackupPane extends StatelessWidget {
  const DesktopBackupPane({super.key});

  @override
  Widget build(BuildContext context) {
    return const BackupPage(embedded: true);
  }
}
