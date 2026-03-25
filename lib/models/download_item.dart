class DownloadItem {
  final String id;
  final String url;
  final String? videoUrl;
  final String? filePath;
  final String? thumbnailUrl;
  final String? caption;
  final DownloadStatus status;
  final DateTime createdAt;
  final String? error;

  DownloadItem({
    required this.id,
    required this.url,
    this.videoUrl,
    this.filePath,
    this.thumbnailUrl,
    this.caption,
    this.status = DownloadStatus.pending,
    DateTime? createdAt,
    this.error,
  }) : createdAt = createdAt ?? DateTime.now();

  DownloadItem copyWith({
    String? videoUrl,
    String? filePath,
    String? thumbnailUrl,
    String? caption,
    DownloadStatus? status,
    String? error,
  }) {
    return DownloadItem(
      id: id,
      url: url,
      videoUrl: videoUrl ?? this.videoUrl,
      filePath: filePath ?? this.filePath,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      caption: caption ?? this.caption,
      status: status ?? this.status,
      createdAt: createdAt,
      error: error ?? this.error,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'videoUrl': videoUrl,
    'filePath': filePath,
    'thumbnailUrl': thumbnailUrl,
    'caption': caption,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'error': error,
  };

  factory DownloadItem.fromJson(Map<String, dynamic> json) => DownloadItem(
    id: json['id'],
    url: json['url'],
    videoUrl: json['videoUrl'],
    filePath: json['filePath'],
    thumbnailUrl: json['thumbnailUrl'],
    caption: json['caption'],
    status: DownloadStatus.values.byName(json['status'] ?? 'pending'),
    createdAt: DateTime.parse(json['createdAt']),
    error: json['error'],
  );
}

enum DownloadStatus { pending, downloading, completed, failed }
