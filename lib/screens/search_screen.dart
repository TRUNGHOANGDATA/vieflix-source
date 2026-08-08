import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../constants/catalog.dart';
import '../models/movie.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/movie_card.dart';
import 'detail_screen.dart';
import 'category_list_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _q = '';
  Timer? _debounce;
  List<Movie> _last = []; // giữ kết quả cũ để hiện trong lúc đang tìm cái mới
  final _controller = TextEditingController();

  // Tìm kiếm bằng giọng nói (chỉ Android/TV có hỗ trợ)
  final SpeechToText _speech = SpeechToText();
  bool _speechAvail = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvail = await _speech.initialize(
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') {
            if (mounted) setState(() => _listening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
    } catch (_) {
      _speechAvail = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleListen() async {
    if (!_speechAvail) return;
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        localeId: 'vi_VN',
        listenFor: const Duration(seconds: 12),
        pauseFor: const Duration(seconds: 3),
      ),
      onResult: (r) {
        final text = r.recognizedWords;
        _controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        _onChanged(text);
        if (r.finalResult && mounted) setState(() => _listening = false);
      },
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    if (Platform.isAndroid) _speech.cancel();
    super.dispose();
  }

  // Chờ gõ xong 0.25s mới tìm -> tránh bắn request liên tục theo từng phím
  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _q = v);
    });
  }

  void _browse(String title, BrowseQuery query) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => CategoryListScreen(title: title, query: query)));

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: _listening ? 'Đang nghe… hãy nói tên phim' : 'Tìm phim theo tên...',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.search, color: Colors.white54),
            // Nút micro: chỉ hiện khi thiết bị hỗ trợ giọng nói (Android/TV)
            suffixIcon: _speechAvail
                ? IconButton(
                    tooltip: _listening ? 'Dừng nghe' : 'Tìm bằng giọng nói',
                    icon: Icon(_listening ? Icons.mic : Icons.mic_none,
                        color: _listening ? kRed : Colors.white54),
                    onPressed: _toggleListen,
                  )
                : null,
            filled: true, fillColor: kSurface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
          onChanged: _onChanged,
        ),
      ),
      Expanded(
        child: _q.trim().length < 2 ? _browseHub() : _results(),
      ),
    ]);
  }

  // Khi chưa gõ gì: cho duyệt nhanh theo Thể loại / Quốc gia
  Widget _browseHub() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Tìm theo thể loại', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final g in kGenres)
          ActionChip(
            backgroundColor: kSurface,
            label: Text(g.label, style: const TextStyle(color: Colors.white)),
            onPressed: () => _browse(g.label, BrowseQuery('genre', g.slug)),
          ),
      ]),
      const SizedBox(height: 24),
      const Text('Tìm theo quốc gia', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in kCountries)
          ActionChip(
            backgroundColor: kSurface,
            label: Text(c.label, style: const TextStyle(color: Colors.white)),
            onPressed: () => _browse('Phim ${c.label}', BrowseQuery('country', c.slug)),
          ),
      ]),
      const SizedBox(height: 24),
      const Text('Tìm theo năm', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final y in kYears)
          ActionChip(
            backgroundColor: kSurface,
            label: Text(y, style: const TextStyle(color: Colors.white)),
            onPressed: () => _browse('Phim năm $y', BrowseQuery('year', y)),
          ),
      ]),
    ]);
  }

  Widget _grid(List<Movie> list) => GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 200, childAspectRatio: 0.6, crossAxisSpacing: 8, mainAxisSpacing: 8),
        itemCount: list.length,
        itemBuilder: (c, i) {
          final m = list[i];
          return MovieCard(movie: m, onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => DetailScreen(slug: m.slug, title: m.name))));
        },
      );

  Widget _results() {
    return ref.watch(searchProvider(_q)).when(
          data: (list) {
            _last = list;
            return list.isEmpty
                ? const Center(child: Text('Không tìm thấy phim', style: TextStyle(color: Colors.white38)))
                : _grid(list);
          },
          error: (e, _) => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Lỗi tải dữ liệu', style: TextStyle(color: Colors.white38)),
              TextButton(onPressed: () => ref.invalidate(searchProvider(_q)), child: const Text('Thử lại', style: TextStyle(color: kRed))),
            ]),
          ),
          // Đang tìm: giữ kết quả cũ + thanh nạp mảnh, thay vì trắng màn
          loading: () => _last.isEmpty
              ? const Center(child: CircularProgressIndicator(color: kRed))
              : Stack(children: [
                  _grid(_last),
                  const Align(
                    alignment: Alignment.topCenter,
                    child: LinearProgressIndicator(color: kRed, backgroundColor: Colors.transparent, minHeight: 2),
                  ),
                ]),
        );
  }
}
