import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/download_item.dart';

class DownloadCard extends StatelessWidget {
  final DownloadItem item;
  final VoidCallback? onRetry;

  const DownloadCard({
    super.key,
    required this.item,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: _statusColor.withOpacity(0.12),
            ),
            child: Center(child: _statusIcon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.caption ?? _shortUrl,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  _statusText,
                  style: TextStyle(
                    fontSize: 11,
                    color: _statusColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          if (item.status == DownloadStatus.completed)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: item.url));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Link copied'),
                    duration: Duration(seconds: 1),
                    backgroundColor: Color(0xFF1A1A1A),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
            ),
          if (item.status == DownloadStatus.failed && onRetry != null)
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String get _shortUrl {
    try {
      final uri = Uri.parse(item.url);
      return uri.path.length > 30 ? '${uri.path.substring(0, 30)}...' : uri.path;
    } catch (_) {
      return item.url;
    }
  }

  String get _statusText {
    switch (item.status) {
      case DownloadStatus.pending:
        return 'Queued';
      case DownloadStatus.downloading:
        return 'Downloading...';
      case DownloadStatus.completed:
        return 'Saved • ${DateFormat('HH:mm').format(item.createdAt)}';
      case DownloadStatus.failed:
        return item.error ?? 'Failed';
    }
  }

  Color get _statusColor {
    switch (item.status) {
      case DownloadStatus.pending:
        return Colors.white.withOpacity(0.4);
      case DownloadStatus.downloading:
        return Colors.white;
      case DownloadStatus.completed:
        return const Color(0xFF4ADE80);
      case DownloadStatus.failed:
        return const Color(0xFFF87171);
    }
  }

  Widget get _statusIcon {
    switch (item.status) {
      case DownloadStatus.pending:
        return Icon(Icons.schedule, size: 16, color: Colors.white.withOpacity(0.3));
      case DownloadStatus.downloading:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
      case DownloadStatus.completed:
        return const Icon(Icons.check_rounded, size: 16, color: Color(0xFF4ADE80));
      case DownloadStatus.failed:
        return const Icon(Icons.close_rounded, size: 16, color: Color(0xFFF87171));
    }
  }
}
