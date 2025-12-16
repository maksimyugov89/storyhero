import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/backend_api.dart';

class ChildPhotosNotifier extends StateNotifier<List<String>> {
  final Ref ref;
  final String childId;

  ChildPhotosNotifier({
    required this.ref,
    required this.childId,
  }) : super([]) {
    _init();
  }

  Future<void> _init() async {
    if (state.isNotEmpty) return;
    
    try {
      final api = ref.read(backendApiProvider);
      final children = await api.getChildren();
      final child = children.firstWhere((c) => c.id == childId, orElse: () => throw Exception('Child not found'));
      
      if (child.faceUrl != null && child.faceUrl!.isNotEmpty) {
        state = [child.faceUrl!];
      }
    } catch (e) {
      // Ignore errors during initialization
    }
  }

  void addPhoto(String photoUrl) {
    if (state.length >= 5) {
      return;
    }
    if (!state.contains(photoUrl)) {
      state = [...state, photoUrl];
    }
  }

  void setAvatar(String photoUrl) {
    if (!state.contains(photoUrl)) {
      return;
    }
    final newState = List<String>.from(state);
    newState.remove(photoUrl);
    newState.insert(0, photoUrl);
    state = newState;
  }

  void removePhoto(String photoUrl) {
    state = state.where((url) => url != photoUrl).toList();
  }
}

final childPhotosProvider = StateNotifierProvider.autoDispose
    .family<ChildPhotosNotifier, List<String>, String>(
  (ref, childId) => ChildPhotosNotifier(ref: ref, childId: childId),
);

