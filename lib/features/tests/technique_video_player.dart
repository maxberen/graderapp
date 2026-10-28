import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/network/api_client.dart';

/// Porteado de km-technique-video-player (main.js:40800-40914) — antes de
/// reproducir muestra una foto de fondo decorativa random (BG/KRAV2..9.jpeg
/// en el original) con botón play; al tocar reproduce el video real de la
/// técnica desde `{endpoint}/Videos/{código}.mp4` (confirmado con curl
/// contra producción: J1C1.mp4 existe, 200 OK, video/mp4, soporta range
/// requests).
///
/// Transmite en vivo con `VideoPlayerController.networkUrl` (ExoPlayer en
/// Android / AVPlayer en iOS ya hacen streaming progresivo por HTTP range
/// requests nativamente — no hace falta servidor de streaming dedicado, el
/// servidor HTTP normal que confirmamos ya alcanza). Empieza a reproducir
/// en cuanto hay buffer suficiente, no espera la descarga completa.
///
/// Esto requiere que el cliente HTTP NATIVO de la plataforma confíe en el
/// certificado real del servidor — a diferencia de Dio (que tiene su
/// propio SecurityContext, ver api_client.dart), video_player usa su
/// propio stack de red. Por eso la raíz de confianza también está
/// declarada a nivel de toda la app en
/// android/app/src/main/res/xml/network_security_config.xml — sin eso,
/// en un Android sin Google Mobile Services esto fallaba la validación TLS
/// en cada fragmento pedido, sintiéndose como una descarga eternamente
/// lenta en vez de un error claro.
class TechniqueVideoPlayer extends StatefulWidget {
  const TechniqueVideoPlayer({super.key, required this.techniqueCode});

  final String techniqueCode;

  @override
  State<TechniqueVideoPlayer> createState() => _TechniqueVideoPlayerState();
}

class _TechniqueVideoPlayerState extends State<TechniqueVideoPlayer> {
  VideoPlayerController? _controller;
  bool _playing = false;
  late final int _bgIndex = Random().nextInt(8) + 2; // KRAV2..KRAV9

  String get _videoUrl =>
      '$kProductionBaseUrl/Videos/${widget.techniqueCode}.mp4';

  @override
  void didUpdateWidget(covariant TechniqueVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.techniqueCode != widget.techniqueCode) {
      _controller?.dispose();
      _controller = null;
      _playing = false;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    // Algunas técnicas son encabezados/introducciones sin video propio —
    // llegan con `code` vacío desde el servidor (confirmado en vivo: la
    // primera "técnica" de muchos tests reales es un ítem de texto tipo
    // "Safety in training and vulnerable points", sin código). Con code
    // vacío la URL queda ".../Videos/.mp4" y el servidor devuelve 404 —
    // no es un video roto, es que no existe para este ítem.
    if (widget.techniqueCode.isEmpty) return;

    final controller = VideoPlayerController.networkUrl(Uri.parse(_videoUrl));
    setState(() {
      _controller = controller;
      _playing = true;
    });
    try {
      await controller.initialize();
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() => _playing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Video not available')));
      }
    }
  }

  void _close() {
    _controller?.pause();
    setState(() => _playing = false);
  }

  Future<void> _openFullscreen() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    controller.pause();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoFullscreenScreen(controller: controller),
        fullscreenDialog: true,
      ),
    );
    if (mounted) controller.play();
  }

  @override
  Widget build(BuildContext context) {
    if (_playing) {
      return SizedBox(
        height: 190,
        child: _controller?.value.isInitialized ?? false
            ? Stack(
                children: [
                  Positioned.fill(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.size.width,
                        height: _controller!.value.size.height,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.fullscreen,
                            color: Colors.white,
                          ),
                          onPressed: _openFullscreen,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: _close,
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : const ColoredBox(
                color: Colors.black,
                child: Center(child: CircularProgressIndicator()),
              ),
      );
    }

    return GestureDetector(
      onTap: _play,
      child: Container(
        height: 190,
        width: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/bg/krav$_bgIndex.jpeg'),
            fit: BoxFit.cover,
            onError: (_, _) {},
          ),
          color: Colors.black,
        ),
        child: widget.techniqueCode.isEmpty
            ? null
            : const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 48,
                ),
              ),
      ),
    );
  }
}

/// Reproductor en pantalla completa (rotado a horizontal, barras del
/// sistema ocultas) — igual al comportamiento de la app real en
/// producción. Reusa el mismo `VideoPlayerController` ya inicializado por
/// [TechniqueVideoPlayer] en vez de crear uno nuevo (evita volver a pedir
/// el video de cero).
class VideoFullscreenScreen extends StatefulWidget {
  const VideoFullscreenScreen({super.key, required this.controller});

  final VideoPlayerController controller;

  @override
  State<VideoFullscreenScreen> createState() => _VideoFullscreenScreenState();
}

class _VideoFullscreenScreenState extends State<VideoFullscreenScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    widget.controller.play();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      widget.controller.value.isPlaying
          ? widget.controller.pause()
          : widget.controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: _togglePlayPause,
          child: Stack(
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio == 0
                      ? 16 / 9
                      : controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white38,
                    backgroundColor: Colors.white12,
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
