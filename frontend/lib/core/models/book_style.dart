/// Модель стиля книги
class BookStyle {
  final String id;
  final String name;
  final String description;
  final bool isPremium;
  final String? iconAsset;

  const BookStyle({
    required this.id,
    required this.name,
    required this.description,
    this.isPremium = false,
    this.iconAsset,
  });
}

/// Все доступные стили книг (28 стилей)
/// 5 бесплатных + 23 премиум
const List<BookStyle> allBookStyles = [
  // ========== БЕСПЛАТНЫЕ СТИЛИ (5) ==========
  BookStyle(
    id: 'classic',
    name: 'Классический',
    description: 'Традиционные детские иллюстрации',
    isPremium: false,
  ),
  BookStyle(
    id: 'cartoon',
    name: 'Мультяшный',
    description: 'Яркие мультипликационные герои',
    isPremium: false,
  ),
  BookStyle(
    id: 'fairytale',
    name: 'Сказочный',
    description: 'Волшебные иллюстрации из сказок',
    isPremium: false,
  ),
  BookStyle(
    id: 'watercolor',
    name: 'Акварельный',
    description: 'Мягкие акварельные рисунки',
    isPremium: false,
  ),
  BookStyle(
    id: 'pencil',
    name: 'Карандашный',
    description: 'Нежные карандашные наброски',
    isPremium: false,
  ),

  // ========== ПРЕМИУМ СТИЛИ (20) ==========
  
  // Известные студии
  BookStyle(
    id: 'disney',
    name: 'Disney',
    description: 'Волшебный стиль Disney',
    isPremium: true,
  ),
  BookStyle(
    id: 'pixar',
    name: 'Pixar',
    description: 'Стиль анимации Pixar',
    isPremium: true,
  ),
  BookStyle(
    id: 'ghibli',
    name: 'Аниме Гибли',
    description: 'Стиль студии Ghibli',
    isPremium: true,
  ),
  BookStyle(
    id: 'dreamworks',
    name: 'Мультфильмы',
    description: 'Стиль популярных мультфильмов',
    isPremium: true,
  ),
  BookStyle(
    id: 'marvel',
    name: 'Марвел',
    description: 'Стиль комиксов Marvel',
    isPremium: true,
  ),
  BookStyle(
    id: 'dc',
    name: 'DC',
    description: 'Стиль комиксов DC',
    isPremium: true,
  ),
  BookStyle(
    id: 'anime',
    name: 'Аниме',
    description: 'Японский аниме стиль',
    isPremium: true,
  ),

  // Художественные стили
  BookStyle(
    id: 'oil_painting',
    name: 'Живопись маслом',
    description: 'Классическая масляная живопись',
    isPremium: true,
  ),
  BookStyle(
    id: 'impressionism',
    name: 'Импрессионизм',
    description: 'Лёгкие мазки импрессионистов',
    isPremium: true,
  ),
  BookStyle(
    id: 'pastel',
    name: 'Пастель',
    description: 'Нежные пастельные тона',
    isPremium: true,
  ),
  BookStyle(
    id: 'gouache',
    name: 'Гуашь',
    description: 'Яркие гуашевые иллюстрации',
    isPremium: true,
  ),
  BookStyle(
    id: 'digital_art',
    name: 'Цифровой арт',
    description: 'Современное цифровое искусство',
    isPremium: true,
  ),

  // Тематические стили
  BookStyle(
    id: 'fantasy',
    name: 'Фэнтези',
    description: 'Магический мир фэнтези',
    isPremium: true,
  ),
  BookStyle(
    id: 'adventure',
    name: 'Приключения',
    description: 'Динамичный приключенческий стиль',
    isPremium: true,
  ),
  BookStyle(
    id: 'space',
    name: 'Космический',
    description: 'Космические приключения',
    isPremium: true,
  ),
  BookStyle(
    id: 'underwater',
    name: 'Подводный мир',
    description: 'Морские глубины и океан',
    isPremium: true,
  ),
  BookStyle(
    id: 'forest',
    name: 'Лесная сказка',
    description: 'Волшебный лес и его обитатели',
    isPremium: true,
  ),
  BookStyle(
    id: 'winter',
    name: 'Зимняя сказка',
    description: 'Снежные пейзажи и зимние чудеса',
    isPremium: true,
  ),

  // Детские стили
  BookStyle(
    id: 'cute',
    name: 'Милашки',
    description: 'Очень милые персонажи',
    isPremium: true,
  ),
  BookStyle(
    id: 'funny',
    name: 'Весёлый',
    description: 'Забавные и смешные иллюстрации',
    isPremium: true,
  ),
  BookStyle(
    id: 'educational',
    name: 'Познавательный',
    description: 'Обучающий стиль иллюстраций',
    isPremium: true,
  ),
  BookStyle(
    id: 'retro',
    name: 'Ретро',
    description: 'Стиль советских мультфильмов',
    isPremium: true,
  ),
  BookStyle(
    id: 'pop_art',
    name: 'Поп-арт',
    description: 'Яркий современный поп-арт',
    isPremium: true,
  ),
];

/// Получить только бесплатные стили
List<BookStyle> get freeStyles => allBookStyles.where((s) => !s.isPremium).toList();

/// Получить только премиум стили
List<BookStyle> get premiumStyles => allBookStyles.where((s) => s.isPremium).toList();


