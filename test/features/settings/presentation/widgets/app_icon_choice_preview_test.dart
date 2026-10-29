import 'package:flutter_test/flutter_test.dart';
import 'package:fluxer_app/features/settings/domain/app_icon_choice.dart';
import 'package:fluxer_app/features/settings/domain/app_icon_preview_assets.dart';
import 'package:fluxer_app/features/settings/presentation/widgets/app_icon_choice_preview.dart';
import 'package:fluxer_app/material_ui.dart';

void main() {
  testWidgets('android preview is clipped with ClipRRect', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppIconChoicePreview(
          choice: AppIconChoice(
            alternateIconName: 'rainbow',
            previewAssetPath: AppIconPreviewAssets.androidRainbow,
            label: (_) => 'Rainbow',
          ),
        ),
      ),
    );

    expect(find.byType(ClipRRect), findsOneWidget);
  });

  testWidgets('ios preview is not clipped', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppIconChoicePreview(
          choice: AppIconChoice(
            alternateIconName: 'rainbow',
            previewAssetPath: AppIconPreviewAssets.iosRainbow,
            label: (_) => 'Rainbow',
          ),
        ),
      ),
    );

    expect(find.byType(ClipRRect), findsNothing);
  });
}
