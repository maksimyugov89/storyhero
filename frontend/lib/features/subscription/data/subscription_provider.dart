import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/backend_api.dart';

const _subscriptionKey = 'is_subscribed';
const _storage = FlutterSecureStorage();

/// Провайдер статуса подписки
final subscriptionProvider = StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  return SubscriptionNotifier(ref);
});

/// Состояние подписки
class SubscriptionState {
  final bool isSubscribed;
  final bool isLoading;
  final String? error;
  final DateTime? expiresAt;

  const SubscriptionState({
    this.isSubscribed = false,
    this.isLoading = false,
    this.error,
    this.expiresAt,
  });

  SubscriptionState copyWith({
    bool? isSubscribed,
    bool? isLoading,
    String? error,
    DateTime? expiresAt,
  }) {
    return SubscriptionState(
      isSubscribed: isSubscribed ?? this.isSubscribed,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

/// Нотифаер для управления подпиской
class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  final Ref _ref;

  SubscriptionNotifier(this._ref) : super(const SubscriptionState()) {
    _loadSubscriptionStatus();
  }

  /// Загрузить статус подписки из хранилища и с сервера
  Future<void> _loadSubscriptionStatus() async {
    state = state.copyWith(isLoading: true);
    
    try {
      // Сначала проверяем локальное хранилище
      final localStatus = await _storage.read(key: _subscriptionKey);
      if (localStatus == 'true') {
        state = state.copyWith(isSubscribed: true, isLoading: false);
      }
      
      // Затем синхронизируем с сервером
      await checkSubscription();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Проверить статус подписки на сервере
  Future<void> checkSubscription() async {
    try {
      final api = _ref.read(backendApiProvider);
      final result = await api.checkSubscription();
      
      state = state.copyWith(
        isSubscribed: result['is_subscribed'] == true,
        expiresAt: result['expires_at'] != null 
            ? DateTime.parse(result['expires_at']) 
            : null,
        isLoading: false,
      );
      
      // Сохраняем локально
      await _storage.write(
        key: _subscriptionKey,
        value: state.isSubscribed.toString(),
      );
    } catch (e) {
      // В случае ошибки используем локальный статус
      state = state.copyWith(isLoading: false);
    }
  }

  /// Оформить подписку
  Future<bool> subscribe() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final api = _ref.read(backendApiProvider);
      final result = await api.createSubscription();
      
      if (result['status'] == 'success') {
        state = state.copyWith(
          isSubscribed: true,
          isLoading: false,
          expiresAt: result['expires_at'] != null 
              ? DateTime.parse(result['expires_at']) 
              : null,
        );
        
        // Сохраняем локально
        await _storage.write(key: _subscriptionKey, value: 'true');
        
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result['message'] ?? 'Ошибка оформления подписки',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Ошибка: ${e.toString()}',
      );
      return false;
    }
  }

  /// Очистить статус подписки (при выходе)
  Future<void> clearSubscription() async {
    await _storage.delete(key: _subscriptionKey);
    state = const SubscriptionState();
  }
}

/// Простой провайдер для проверки подписки
final isSubscribedProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionProvider).isSubscribed;
});

