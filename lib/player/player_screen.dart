import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/episode.dart';
import 'ad_blocker.dart';

class PlayerScreen extends StatefulWidget {
  final String title, embedUrl;
  final List<Episode> episodes;
  final int startIndex;
  final void Function(Episode) onEpisodeChange;
  const PlayerScreen({
    super.key, required this.title, required this.embedUrl,
    required this.episodes, required this.startIndex, required this.onEpisodeChange,
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
  }

  void _goto(int i) {
    if (i < 0 || i >= widget.episodes.length) return;
    final ep = widget.episodes[i];
    setState(() { _idx = i; _url = ep.embed; });
    widget.onEpisodeChange(ep);
    _c?.loadUrl(urlRequest: URLRequest(url: WebUri(ep.embed)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
              Expanded(child: Text(widget.title, style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis)),
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
          if (widget.episodes.length > 1)
            Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(icon: const Icon(Icons.skip_previous, color: Colors.white), onPressed: _idx > 0 ? () => _goto(_idx - 1) : null),
                Text('Tập ${widget.episodes[_idx].name}', style: const TextStyle(color: Colors.white)),
                IconButton(icon: const Icon(Icons.skip_next, color: Colors.white), onPressed: _idx < widget.episodes.length - 1 ? () => _goto(_idx + 1) : null),
              ]),
            ),
        ]),
      ),
    );
  }
}
