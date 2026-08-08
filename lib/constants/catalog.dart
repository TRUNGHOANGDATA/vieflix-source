class CatalogEntry {
  final String label, slug;
  const CatalogEntry(this.label, this.slug);
}

const kTypes = [
  CatalogEntry('Phim Bộ', 'phim-bo'),
  CatalogEntry('Phim Lẻ', 'phim-le'),
  CatalogEntry('Hoạt Hình', 'hoat-hinh'),
  CatalogEntry('TV Shows', 'tv-shows'),
];

const kGenres = [
  CatalogEntry('Hành Động', 'hanh-dong'),
  CatalogEntry('Tình Cảm', 'tinh-cam'),
  CatalogEntry('Hài', 'hai'),
  CatalogEntry('Kinh Dị', 'kinh-di'),
  CatalogEntry('Tâm Lý', 'tam-ly'),
  CatalogEntry('Cổ Trang', 'co-trang'),
  CatalogEntry('Viễn Tưởng', 'vien-tuong'),
  CatalogEntry('Hình Sự', 'hinh-su'),
  CatalogEntry('Chiến Tranh', 'chien-tranh'),
  CatalogEntry('Hoạt Hình', 'hoat-hinh'),
];

const kCountries = [
  CatalogEntry('Hàn Quốc', 'han-quoc'),
  CatalogEntry('Trung Quốc', 'trung-quoc'),
  CatalogEntry('Nhật Bản', 'nhat-ban'),
  CatalogEntry('Âu Mỹ', 'au-my'),
  CatalogEntry('Thái Lan', 'thai-lan'),
  CatalogEntry('Việt Nam', 'viet-nam'),
  CatalogEntry('Ấn Độ', 'an-do'),
];

const kYears = ['2026', '2025', '2024', '2023', '2022', '2021', '2020', '2019'];
