/// Константы маршрутов приложения
class RouteNames {
  // Auth routes
  static const String splash = '/auth/splash';
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  
  // App routes
  static const String home = '/app/home';
  static const String children = '/app/children';
  static const String childrenNew = '/app/children/new';
  static const String childProfile = '/app/children/:id';
  static const String childEdit = '/app/children/:id/edit';
  static const String childBooks = '/app/children/:id/books';
  
  static const String books = '/app/books';
  static const String bookView = '/app/books/:id';
  static const String bookSceneEdit = '/app/books/:id/scene/:index';
  static const String bookTextEdit = '/app/books/:id/scene/:index/text';
  static const String bookImageEdit = '/app/books/:id/scene/:index/image';
  static const String bookFinalize = '/app/books/:id/finalize';
  static const String bookFinalizePreview = '/app/books/:id/finalize/preview';
  static const String bookComplete = '/app/books/:id/complete';
  static const String bookOrder = '/app/books/:id/order';
  
  static const String generate = '/app/generate';
  static const String taskStatus = '/app/tasks/:id';
  
  static const String settings = '/app/settings';
  static const String help = '/app/settings/help';
  static const String supportMessageDetail = '/app/settings/help/message/:id';
  static const String subscription = '/app/settings/subscription';
  static const String payment = '/app/payment/:bookId';
}









