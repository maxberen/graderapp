import 'dart:async';

import 'package:flutter/material.dart';

/// Porteado de km-test-timer (main.js:38862-38920) — cronómetro simple de
/// sesión (HH:MM:SS), independiente del video de la técnica. Start/pause al
/// tocar el tiempo, botón para cerrar la barra.
class TestSessionTimer extends StatefulWidget {
  const TestSessionTimer({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<TestSessionTimer> createState() => _TestSessionTimerState();
}

class _TestSessionTimerState extends State<TestSessionTimer> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _running = false;

  void _toggle() {
    setState(() => _running = !_running);
    if (_running) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _elapsed += const Duration(seconds: 1));
      });
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formatted {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = _elapsed.inHours;
    final m = _elapsed.inMinutes % 60;
    final s = _elapsed.inSeconds % 60;
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      color: Colors.black,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _toggle,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _running ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatted,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }
}
