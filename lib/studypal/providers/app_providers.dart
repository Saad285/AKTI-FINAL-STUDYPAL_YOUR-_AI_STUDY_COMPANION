import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../chatbot/chat_bot_provider.dart';
import 'auth_provider.dart';
import 'teacher_provider.dart';

/// Central place to register app-wide providers.
///
/// Keeping this list in one file helps avoid re-creating providers deep in the
/// widget tree (which can look like "reloads" when screens rebuild).
List<SingleChildWidget> get appProviders => [
  ChangeNotifierProvider(create: (_) => AuthProvider()),
  ChangeNotifierProvider(create: (_) => TeacherProvider()),
  ChangeNotifierProvider(create: (_) => ChatBotProvider()),
];
