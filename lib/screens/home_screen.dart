import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/download_item.dart';
import '../services/download_service.dart';
import '../services/history_service.dart';
import '../services/instagram_service.dart';
import '../services/notification_service.dart';
import '../widgets/download_card.dart';
import '../widgets/status_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _urlController = TextEditingController();
  List<DownloadItem> _history = [];
  bool _watching = false;
  bool _isDownloading = false;
  bool _accessibilityEnabled = false;
  StreamSubscription<String>? _clipSub;
  Timer? _pollTimer;
  final Set<String> _processedUrls = {};
  String _lastClipText = '';

  static const _clipboardChannel = MethodChannel('com.instagrab/clipboard');
  static const _clipboardEvents = EventChannel('com.instagrab/clipboard_events');
  static const _accessibilityChannel = MethodChannel('com.instagrab/accessibility');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadHistory();
    _requestPermissions();
    _checkPendingShare();
    _checkAccessibility();
    // Auto-start clipboard watcher
    WidgetsBinding.instance.addPostFrameCallback((_) => _toggleWatching());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clipSub?.cancel();
    _pollTimer?.cancel();
    _urlController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingAccessibilityUrl();
      if (_watching) _checkClipboard();
      _checkAccessibility();
    }
  }

  Future<void> _checkPendingAccessibilityUrl() async {
    try {
      final url = await _accessibilityChannel.invokeMethod<String>('getPendingUrl');
      if (url != null && url.isNotEmpty) {
        _onClipboardText(url);
      }
    } catch (_) {}
  }

  Future<void> _checkAccessibility() async {
    try {
      final enabled = await _accessibilityChannel.invokeMethod<bool>('isEnabled');
      if (mounted) setState(() => _accessibilityEnabled = enabled ?? false);
    } catch (_) {}
  }

  Future<void> _openAccessibilitySettings() async {
    try {
      await _accessibilityChannel.invokeMethod('openSettings');
    } catch (_) {}
  }

  Future<void> _checkPendingShare() async {
    try {
      final text = await _clipboardChannel.invokeMethod<String>('getPendingShare');
      if (text != null && text.isNotEmpty) {
        _onClipboardText(text);
      }
    } catch (_) {}
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.notification,
      Permission.storage,
      Permission.videos,
      Permission.photos,
    ].request();
  }

  Future<void> _loadHistory() async {
    final items = await HistoryService.getHistory();
    if (mounted) setState(() => _history = items);
  }

  void _toggleWatching() {
    if (_watching) {
      _clipSub?.cancel();
      _clipSub = null;
      _pollTimer?.cancel();
      _pollTimer = null;
      setState(() => _watching = false);
    } else {
      // Listen via native EventChannel
      _clipSub = _clipboardEvents
          .receiveBroadcastStream()
          .map((event) => event.toString())
          .listen(_onClipboardText);

      // Poll every 1.5 seconds: check clipboard (foreground) + pending URLs from accessibility service (background)
      _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
        _checkClipboard();
        _checkPendingAccessibilityUrl();
      });

      // Check immediately
      _checkClipboard();

      setState(() => _watching = true);
    }
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      if (text.isNotEmpty && text != _lastClipText) {
        _lastClipText = text;
        _onClipboardText(text);
      }
    } catch (_) {}
  }

  void _onClipboardText(String text) {
    final url = InstagramService.extractInstagramUrl(text);
    if (url != null && !_processedUrls.contains(url)) {
      _processedUrls.add(url);
      _startDownload(url);
    }
  }

  Future<void> _startDownload(String url) async {
    setState(() => _isDownloading = true);

    final item = DownloadItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      url: url,
      status: DownloadStatus.downloading,
    );

    await HistoryService.addItem(item);
    setState(() => _history.insert(0, item));

    await NotificationService.showDownloadStarted(url);

    final result = await DownloadService.downloadReel(item);

    await HistoryService.updateItem(result);
    if (mounted) {
      setState(() {
        final idx = _history.indexWhere((e) => e.id == item.id);
        if (idx != -1) _history[idx] = result;
        _isDownloading = false;
      });
    }

    if (result.status == DownloadStatus.completed) {
      await NotificationService.showDownloadComplete(url);
    } else {
      await NotificationService.showDownloadFailed(url, result.error ?? 'Unknown error');
    }
  }

  void _handleManualSubmit() {
    final text = _urlController.text.trim();
    if (text.isEmpty) return;
    final url = InstagramService.extractInstagramUrl(text);
    if (url != null) {
      _urlController.clear();
      FocusScope.of(context).unfocus();
      _startDownload(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not a valid Instagram URL'),
          backgroundColor: Color(0xFF1A1A1A),
        ),
      );
    }
  }

  Future<void> _clearHistory() async {
    await HistoryService.clearHistory();
    setState(() => _history.clear());
    _processedUrls.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  const Text(
                    'InstaGrab',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  if (_history.isNotEmpty)
                    GestureDetector(
                      onTap: _clearHistory,
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            StatusBar(
              watching: _watching,
              isDownloading: _isDownloading,
              onToggle: _toggleWatching,
            ),

            const SizedBox(height: 8),

            // Accessibility service banner
            if (!_accessibilityEnabled)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: _openAccessibilitySettings,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1400),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF3D3200)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.accessibility_new, size: 18, color: Color(0xFFFFAA00)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Enable background detection',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFFFAA00)),
                              ),
                              Text(
                                'Auto-download when you copy Instagram links anywhere',
                                style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.4)),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white.withOpacity(0.3)),
                      ],
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF001A00),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF003D00)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.check_circle, size: 16, color: Color(0xFF00CC00)),
                      SizedBox(width: 10),
                      Text(
                        'Background detection active',
                        style: TextStyle(fontSize: 12, color: Color(0xFF00CC00)),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Manual URL input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: TextField(
                        controller: _urlController,
                        style: const TextStyle(fontSize: 13, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Paste Instagram link...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.25),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _handleManualSubmit(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isDownloading ? null : _handleManualSubmit,
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: _isDownloading
                            ? Colors.white.withOpacity(0.04)
                            : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.download_rounded,
                        size: 20,
                        color: _isDownloading
                            ? Colors.white.withOpacity(0.2)
                            : Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Container(
              height: 0.5,
              color: Colors.white.withOpacity(0.06),
            ),

            Expanded(
              child: _history.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.video_library_outlined,
                            size: 40,
                            color: Colors.white.withOpacity(0.1),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No downloads yet',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Turn on the watcher or paste a link above',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.12),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      itemCount: _history.length,
                      itemBuilder: (context, index) {
                        return DownloadCard(
                          item: _history[index],
                          onRetry: () => _startDownload(_history[index].url),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
