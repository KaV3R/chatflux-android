import 'package:fluxer_app/features/settings/domain/app_icon_choice.dart';
import 'package:fluxer_app/features/settings/domain/app_icon_preview_assets.dart';
import 'package:fluxer_app/material_ui.dart';

class AppIconChoicePreview extends StatelessWidget {
  const AppIconChoicePreview({required this.choice, super.key});

  static const Size size = Size(48, 48);

  static double androidPreviewCornerRadius(Size iconSize) {
    return iconSize.width * 0.22;
  }

  final AppIconChoice choice;

  bool get _usesAndroidPreviewAsset {
    return choice.previewAssetPath.startsWith(AppIconPreviewAssets.androidRoot);
  }

  @override
  Widget build(BuildContext context) {
    final Widget image = Image.asset(
      choice.previewAssetPath,
      width: size.width,
      height: size.height,
      fit: BoxFit.cover,
    );

    return ExcludeSemantics(
      child: _usesAndroidPreviewAsset
          ? ClipRRect(
              borderRadius: BorderRadius.circular(
                androidPreviewCornerRadius(size),
              ),
              child: image,
            )
          : image,
    );
  }
}
