/// Этапы генерации книги
enum BookGenerationStep {
  /// Создание профиля ребёнка
  profile,
  
  /// Генерация сюжета
  plot,
  
  /// Генерация текста
  text,
  
  /// Создание промптов изображений
  prompts,
  
  /// Генерация черновых изображений
  draftImages,
  
  /// Генерация финальных изображений
  finalImages,
  
  /// Завершение
  done;

  /// Преобразование строки из backend в enum
  /// Поддерживает значения stage из API документации:
  /// "starting", "creating_plot", "plot_ready", "creating_text", "text_ready",
  /// "creating_prompts", "selecting_style", "generating_draft_images",
  /// "generating_final_images", "completed"
  static BookGenerationStep? fromString(String? step) {
    if (step == null) return null;
    
    final normalized = step.toLowerCase().trim();
    
    switch (normalized) {
      // Новые значения из API документации
      case 'starting':
        return BookGenerationStep.profile;
      case 'creating_plot':
      case 'plot_ready':
        return BookGenerationStep.plot;
      case 'creating_text':
      case 'text_ready':
        return BookGenerationStep.text;
      case 'creating_prompts':
      case 'selecting_style':
        return BookGenerationStep.prompts;
      case 'generating_draft_images':
        return BookGenerationStep.draftImages;
      case 'generating_final_images':
        return BookGenerationStep.finalImages;
      case 'completed':
        return BookGenerationStep.done;
      
      // Старые значения для обратной совместимости
      case 'profile':
      case 'создание профиля':
      case 'профиль':
        return BookGenerationStep.profile;
      case 'plot':
      case 'сюжет':
      case 'генерация сюжета':
      case 'plot_generation':
        return BookGenerationStep.plot;
      case 'text':
      case 'текст':
      case 'генерация текста':
      case 'text_generation':
        return BookGenerationStep.text;
      case 'prompts':
      case 'промпты':
      case 'создание промптов':
      case 'prompt_generation':
        return BookGenerationStep.prompts;
      case 'draft_images':
      case 'draftimages':
      case 'черновые':
      case 'черновые изображения':
      case 'генерация черновых изображений':
        return BookGenerationStep.draftImages;
      case 'final_images':
      case 'finalimages':
      case 'финальные':
      case 'финальные изображения':
      case 'генерация финальных изображений':
        return BookGenerationStep.finalImages;
      case 'done':
      case 'завершение':
      case 'готово':
        return BookGenerationStep.done;
      default:
        return null;
    }
  }

  /// Получить название этапа для отображения
  String get displayName {
    switch (this) {
      case BookGenerationStep.profile:
        return 'Создание профиля ребёнка';
      case BookGenerationStep.plot:
        return 'Генерация сюжета';
      case BookGenerationStep.text:
        return 'Генерация текста';
      case BookGenerationStep.prompts:
        return 'Создание промптов изображений';
      case BookGenerationStep.draftImages:
        return 'Генерация черновых изображений';
      case BookGenerationStep.finalImages:
        return 'Генерация финальных изображений';
      case BookGenerationStep.done:
        return 'Завершение';
    }
  }

  /// Получить описание этапа
  String get description {
    switch (this) {
      case BookGenerationStep.profile:
        return 'Анализ информации о ребёнке';
      case BookGenerationStep.plot:
        return 'Создание уникального сюжета';
      case BookGenerationStep.text:
        return 'Написание текста для каждой сцены';
      case BookGenerationStep.prompts:
        return 'Подготовка описаний для изображений';
      case BookGenerationStep.draftImages:
        return 'Создание предварительных иллюстраций';
      case BookGenerationStep.finalImages:
        return 'Финальная обработка изображений';
      case BookGenerationStep.done:
        return 'Книга готова!';
    }
  }
}

/// Статус генерации книги
class BookGenerationStatus {
  final BookGenerationStep step;
  final String message;
  final double? progress;

  const BookGenerationStatus({
    required this.step,
    required this.message,
    this.progress,
  });
}

