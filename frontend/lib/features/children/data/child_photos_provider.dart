import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/api/backend_api.dart';
import '../../../core/models/child_photo.dart';

/// Провайдер для получения всех фотографий ребенка
/// GET /api/v1/children/{child_id}/photos
final childPhotosProvider = FutureProvider.family<ChildPhotosResponse, String>(
  (ref, childId) async {
    final api = ref.watch(backendApiProvider);
    return await api.getChildPhotos(childId);
  },
);

