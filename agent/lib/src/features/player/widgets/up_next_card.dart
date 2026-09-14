import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// "Up next" card shown when the current lesson reaches >=90% watched
/// (seek-proof: driven by max position reached, not natural completion).
/// Auto-plays the next lesson after [countdownSeconds] unless dismissed.
/// Locked lessons show without auto-play (backend would 403).
class UpNextCard extends StatefulWidget {
  final String nextTitle;
  final String subtitle;
  final bool autoPlay;
  final int countdownSeconds;
  final VoidCallback onPlayNow;
  final VoidCallback onDismiss;

  const UpNextCard({
    super.key,
    required this.nextTitle,
    required this.subtitle,
    required this.autoPlay,
    this.countdownSeconds = 10,
    required this.onPlayNow,
    required this.onDismiss,
  });

  @override
  State<UpNextCard> createState() => _UpNextCardState();
}

class _UpNextCardState extends State<UpNextCard> {
  late int _remaining;
  Timer? _timer;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.countdownSeconds;
    if (widget.autoPlay) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted || _gone) {
          t.cancel();
          return;
        }
        if (_remaining <= 1) {
          t.cancel();
          _gone = true;
          widget.onPlayNow();
        } else {
          setState(() => _remaining--);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _dismiss() {
    if (_gone) return;
    _gone = true;
    _timer?.cancel();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 100,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.skipForward, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Up next',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (widget.autoPlay)
                  Text(
                    '$_remaining s',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                IconButton(
                  icon: const Icon(LucideIcons.x, color: Colors.white70, size: 18),
                  onPressed: _dismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.nextTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      if (_gone) return;
                      _gone = true;
                      _timer?.cancel();
                      widget.onPlayNow();
                    },
                    icon: const Icon(LucideIcons.play, size: 16),
                    label: const Text('Play now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}