class Paginated<T> {
  final List<T> items;
  final int currentPage, totalPage;
  Paginated({required this.items, required this.currentPage, required this.totalPage});
}
