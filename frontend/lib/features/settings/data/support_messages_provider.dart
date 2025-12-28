import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/backend_api.dart';
import '../../../core/models/support_message.dart';

/// Провайдер для получения списка всех сообщений поддержки текущего пользователя
/// Использует autoDispose для автоматической перезагрузки при возврате на экран
final supportMessagesProvider = FutureProvider.autoDispose<List<SupportMessage>>((ref) async {
  final api = ref.watch(backendApiProvider);
  return await api.getSupportMessages();
});

/// Провайдер для получения конкретного сообщения поддержки по ID
/// Использует autoDispose для автоматической перезагрузки при возврате на экран
final supportMessageDetailProvider = FutureProvider.family.autoDispose<SupportMessageDetail, String>((ref, messageId) async {
  final api = ref.watch(backendApiProvider);
  return await api.getSupportMessageDetail(messageId);
});

