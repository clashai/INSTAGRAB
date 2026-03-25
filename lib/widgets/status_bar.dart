import 'package:flutter/material.dart';

class StatusBar extends StatelessWidget {
  final bool watching;
  final bool isDownloading;
  final VoidCallback onToggle;

  const StatusBar({
    super.key,
    required this.watching,
    required this.isDownloading,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: watching
                ? Colors.white.withOpacity(0.08)
                : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: watching
                  ? Colors.white.withOpacity(0.15)
                  : Colors.white.withOpacity(0.06),
            ),
          ),
          child: Row(
            children: [
              // Animated dot indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: watching
                      ? const Color(0xFF4ADE80)
                      : Colors.white.withOpacity(0.2),
                  boxShadow: watching
                      ? [
                          BoxShadow(
                            color: const Color(0xFF4ADE80).withOpacity(0.4),
                            blurRadius: 6,
                            spreadRadius: 1,
                          )
                        ]
                      : [],
                ),
              ),
              const SizedBox(width: 12),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    watching ? 'Clipboard watcher active' : 'Clipboard watcher off',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(watching ? 0.9 : 0.4),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    watching
                        ? (isDownloading ? 'Downloading...' : 'Waiting for Instagram links')
                        : 'Tap to start monitoring',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(watching ? 0.35 : 0.2),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Toggle visual
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 44,
                height: 24,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: watching
                      ? Colors.white.withOpacity(0.2)
                      : Colors.white.withOpacity(0.08),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 250),
                  alignment: watching ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: watching ? Colors.white : Colors.white.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
