import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Etiqueta compacta de obra compartilhada pelo Loop e pelo perfil.
/// Títulos curtos ficam inteiros; títulos longos deslizam suavemente.
class VideoWorkLabel extends StatefulWidget {
  final String title;
  final String type;
  final String details;

  const VideoWorkLabel({
    super.key,
    required this.title,
    this.type = '',
    this.details = '',
  });

  @override
  State<VideoWorkLabel> createState() => _VideoWorkLabelState();
}

class _VideoWorkLabelState extends State<VideoWorkLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.title.trim().isEmpty
        ? 'Obra não informada'
        : widget.title.trim();
    final type = widget.type.trim().toLowerCase();
    final IconData icon;
    if (type.contains('série') || type.contains('serie')) {
      icon = Icons.tv_rounded;
    } else if (type.contains('livro') || type.contains('book')) {
      icon = Icons.menu_book_rounded;
    } else {
      icon = Icons.movie_rounded;
    }

    const style = TextStyle(
      color: Colors.white,
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
    );
    final painter = TextPainter(
      text: TextSpan(text: name, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();

    // Pequena folga para diferenças de arredondamento entre TextPainter e Text.
    final fullTextWidth = painter.width + 6;
    const maxTextWidth = 129.0;
    const horizontalPadding = 10.0;
    const iconWidth = 14.0;
    const gap = 5.0;
    const borderWidth = 1.0;
    const fixedWidth = horizontalPadding * 2 + iconWidth + gap + borderWidth * 2;
    final visibleWidth = math.min(fullTextWidth, maxTextWidth);
    final needsScroll = fullTextWidth > maxTextWidth;
    final travel = math.max(0.0, fullTextWidth - visibleWidth);

    return Container(
      width: fixedWidth + visibleWidth,
      padding: const EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF21171C).withValues(alpha: .72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconWidth, color: const Color(0xFFFFD5DF)),
          const SizedBox(width: gap),
          SizedBox(
            width: visibleWidth,
            height: 17,
            child: needsScroll
                ? ClipRect(
                    child: AnimatedBuilder(
                      animation: _scrollController,
                      builder: (context, child) {
                        final progress = Curves.easeInOut.transform(
                          _scrollController.value,
                        );
                        return Transform.translate(
                          offset: Offset(-travel * progress, 0),
                          child: child,
                        );
                      },
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: fullTextWidth,
                          child: Text(
                            name,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.visible,
                            style: style,
                          ),
                        ),
                      ),
                    ),
                  )
                : Text(
                    name,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: style,
                  ),
          ),
        ],
      ),
    );
  }
}
