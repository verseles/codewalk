// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../platform/sessions/project_icon_loader.dart';
import '../../shared/sessions/project_icon_data.dart';

/// The same fixed icon slot in project rows, pickers and session tabs.
class ProjectIconView extends StatefulWidget {
  const ProjectIconView({
    super.key,
    this.source,
    this.size = 24,
    this.fallback = Symbols.folder_open,
    this.color,
  });
  final Uri? source;
  final double size;
  final IconData fallback;
  final Color? color;

  @override
  State<ProjectIconView> createState() => _ProjectIconViewState();
}

class _ProjectIconViewState extends State<ProjectIconView> {
  Future<ProjectIconData?>? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ProjectIconView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An equal URL can recover after an offline load or change its artwork.
    // The shared cache reuses the same future until its entry expires.
    _load();
  }

  void _load() =>
      _image = widget.source == null ? null : loadProjectIcon(widget.source!);
  Widget _fallback() =>
      Icon(widget.fallback, size: widget.size, color: widget.color);

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: ExcludeSemantics(
      child: ClipRect(
        child: FutureBuilder<ProjectIconData?>(
          key: ValueKey(widget.source),
          future: _image,
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (data == null) return _fallback();
            if (data.svg) {
              return SvgPicture.memory(
                data.bytes,
                width: widget.size,
                height: widget.size,
                fit: BoxFit.contain,
                placeholderBuilder: (_) => _fallback(),
                errorBuilder: (_, _, _) => _fallback(),
              );
            }
            final pixels =
                (widget.size * MediaQuery.devicePixelRatioOf(context))
                    .ceil()
                    .clamp(1, 128);
            return Image(
              image: ResizeImage(
                MemoryImage(data.bytes),
                width: pixels,
                height: pixels,
                policy: ResizeImagePolicy.fit,
              ),
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _fallback(),
              frameBuilder: (_, child, frame, _) =>
                  frame == null ? _fallback() : child,
            );
          },
        ),
      ),
    ),
  );
}
