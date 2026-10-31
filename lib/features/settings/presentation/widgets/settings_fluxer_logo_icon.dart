import 'package:fluxer_app/core/theme/fluxer_theme_extension.dart';
import 'package:fluxer_app/material_ui.dart';

/// ChatFlux: the cat head, tinted like the other settings icons.
class SettingsFluxerLogoIcon extends StatelessWidget {
  const SettingsFluxerLogoIcon({this.size = 20, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final Color color =
        IconTheme.of(context).color ?? context.colors.textPrimary;
    return ExcludeSemantics(
      child: Image.asset(
        'assets/images/chatflux_cat_monochrome.png',
        width: size,
        height: size,
        color: color,
        colorBlendMode: BlendMode.srcIn,
      ),
    );
  }
}
