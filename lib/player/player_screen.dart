import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/episode.dart';
import '../theme/app_theme.dart';
import 'ad_blocker.dart';

class PlayerScreen extends StatefulWidget {
  final String movieName, posterUrl, embedUrl;
  final List<Episode> episodes;
  final int startIndex;
  final int totalEpisodes; // tổng số tập full của phim (kể cả chưa ra)
  final void Function(Episode) onEpisodeChange;
  const PlayerScreen({
    super.key,
    required this.movieName,
    required this.posterUrl,
    required this.embedUrl,
    required this.episodes,
    required this.startIndex,
    required this.totalEpisodes,
    required this.onEpisodeChange,
  });
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  InAppWebViewController? _c;
  late int _idx;
  late String _url;

  @override
  void initState() {
    super.initState();
    _idx = widget.startIndex < 0 ? 0 : widget.startIndex;
    _url = widget.embedUrl;
    // ESC để thoát khỏi phim đang xem
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent e) {
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
        return true;
      }
    }
    return false;
  }

  void _goto(int i) {
    if (i < 0 || i >= widget.episodes.length) return;
    final ep = widget.episodes[i];
    setState(() {
      _idx = i;
      _url = ep.embed;
    });
    widget.onEpisodeChange(ep);
    _c?.loadUrl(urlRequest: URLRequest(url: WebUri(ep.embed)));
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.totalEpisodes > widget.episodes.length ? widget.totalEpisodes : widget.episodes.length;
    final epName = widget.episodes.isNotEmpty ? widget.episodes[_idx].name : '';
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          // Thanh trên: back + poster + tên đầy đủ + Tập X/Y
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: 'Thoát (ESC)',
                onPressed: () => Navigator.pop(context),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: widget.posterUrl,
                  width: 40, height: 56, fit: BoxFit.cover,
                  placeholder: (c, _) => Container(width: 40, height: 56, color: kSurface),
                  errorWidget: (c, _, __) => Container(width: 40, height: 56, color: kSurface, child: const Icon(Icons.movie, color: Colors.white24, size: 18)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(widget.movieName,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(total > 1 ? 'Tập $epName / $total' : 'Phim lẻ',
                        style: const TextStyle(color: Colors.white60, fontSize: 13)),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text('Nhấn ESC để thoát', style: TextStyle(color: Colors.white24, fontSize: 12)),
              ),
            ]),
          ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_url)),
              initialSettings: InAppWebViewSettings(
                contentBlockers: adContentBlockers(),
                javaScriptCanOpenWindowsAutomatically: false,
                supportMultipleWindows: false,
                mediaPlaybackRequiresUserGesture: false,
                transparentBackground: true,
                userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              ),
              initialUserScripts: UnmodifiableListView([
                UserScript(source: kAntiAdUserScript, injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START),
              ]),
              onWebViewCreated: (c) => _c = c,
              shouldOverrideUrlLoading: (c, action) async {
                final u = action.request.url?.toString() ?? '';
                if (isAdUrl(u)) return NavigationActionPolicy.CANCEL;
                return NavigationActionPolicy.ALLOW;
              },
              onCreateWindow: (c, req) async => false,
            ),
          ),
          // Thanh dưới: chuyển tập
          if (widget.episodes.length > 1)
            Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(icon: const Icon(Icons.skip_previous, color: Colors.white), onPressed: _idx > 0 ? () => _goto(_idx - 1) : null),
                Text('Tập $epName / $total', style: const TextStyle(color: Colors.white)),
                IconButton(icon: const Icon(Icons.skip_next, color: Colors.white), onPressed: _idx < widget.episodes.length - 1 ? () => _goto(_idx + 1) : null),
              ]),
            ),
        ]),
      ),
    );
  }
}
