// Re-export logging package
export 'package:logging/logging.dart';

import 'package:logging/logging.dart';

// Extension methods for backward compatibility
extension LoggerExtensions on Logger {
  // MCP 载荷、地址和子进程错误均不可信，只允许向系统日志发送固定事件。
  void debug(String _) => fine('[McpClient] debug event');
  void error(String _) => severe('[McpClient] error event');
  void warn(String _) => warning('[McpClient] warning event');
}
