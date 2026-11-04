// ChatFlux Shop: "Change display name style" – pick a bought font + effect
// and colour them.

import 'dart:async';

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluxer_app/core/api/fluxer_client_provider.dart';
import 'package:fluxer_app/features/chatflux/shop/chatflux_name_style.dart';
import 'package:fluxer_app/features/chatflux/shop/chatflux_shop_store.dart';

const Color _kSheet = Color(0xFF1F2024);
const Color _kTile = Color(0xFF26272C);
const Color _kTileBorder = Color(0xFF34363C);
const Color _kMuted = Color(0xFFA1A1AA);
const Color _kBrand = Color(0xFF5865F2);

const List<String> kChatFluxNameColorPresets = <String>[
  '#f472b6',
  '#22c55e',
  '#38bdf8',
  '#a855f7',
  '#e11d48',
  '#f97316',
  '#facc15',
  '#ffffff',
];

String _effectLabel(BuildContext c, String effect) => switch (effect) {
  'solid' => chatFluxTr(c, 'Egyszínű', 'Solid'),
  'gradient' => chatFluxTr(c, 'Színátmenet', 'Gradient'),
  'neon' => 'Neon',
  'toon' => chatFluxTr(c, 'Rajzfilm', 'Toon'),
  'pop' => 'Pop',
  'gummy' => chatFluxTr(c, 'Gumicukor', 'Gummy'),
  'prism' => chatFluxTr(c, 'Prizma', 'Prism'),
  'shimmer' => chatFluxTr(c, 'Csillogás', 'Shimmer'),
  _ => effect,
};

/// The user's avatar + name in a chat-like row, drawn in [nameStyle].
class ChatFluxNameStylePreviewRow extends StatelessWidget {
  const ChatFluxNameStylePreviewRow({
    required this.name,
    required this.avatarUrl,
    required this.nameStyle,
    this.large = false,
    super.key,
  });

  final String name;
  final String? avatarUrl;
  final ChatFluxNameStyle nameStyle;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final double avatar = large ? 46 : 28;
    final String? url = avatarUrl;
    return Container(
      padding: EdgeInsets.all(large ? 14 : 8),
      decoration: BoxDecoration(
        color: const Color(0x2E000000),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          ClipOval(
            child: url == null
                ? Container(
                    width: avatar,
                    height: avatar,
                    color: const Color(0xFF4B4F58),
                  )
                : CachedNetworkImage(
                    imageUrl: url,
                    width: avatar,
                    height: avatar,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: avatar,
                      height: avatar,
                      color: const Color(0xFF4B4F58),
                    ),
                  ),
          ),
          SizedBox(width: large ? 12 : 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ChatFluxNameText(
                  text: name,
                  nameStyle: nameStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: large ? 22 : 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: large ? 8 : 5),
                FractionallySizedBox(
                  widthFactor: 0.7,
                  child: Container(
                    height: large ? 9 : 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4B4F58),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatFluxNameStyleEditor extends ConsumerStatefulWidget {
  const ChatFluxNameStyleEditor({
    required this.name,
    required this.avatarUrl,
    required this.onOpenItem,
    super.key,
  });

  final String name;
  final String? avatarUrl;
  final void Function(ChatFluxItem item) onOpenItem;

  static Future<void> show(
    BuildContext context, {
    required String name,
    required String? avatarUrl,
    required void Function(ChatFluxItem item) onOpenItem,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: _kSheet,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext _) => ChatFluxNameStyleEditor(
      name: name,
      avatarUrl: avatarUrl,
      onOpenItem: onOpenItem,
    ),
  );

  @override
  ConsumerState<ChatFluxNameStyleEditor> createState() =>
      _ChatFluxNameStyleEditorState();
}

class _ChatFluxNameStyleEditorState
    extends ConsumerState<ChatFluxNameStyleEditor> {
  final ChatFluxShopStore _store = ChatFluxShopStore.instance;
  String? _font;
  String? _effect;
  List<String> _colors = List<String>.of(kChatFluxDefaultNameColors);
  bool _saving = false;
  bool _saved = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reloadFromMe();
    _store.me.addListener(_onMeChanged);
  }

  @override
  void dispose() {
    _store.me.removeListener(_onMeChanged);
    super.dispose();
  }

  // Something was bought or equipped elsewhere (e.g. from a locked tile).
  void _onMeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _reloadFromMe() {
    final ChatFluxMe? me = _store.me.value;
    _font = me?.equipped['namefont'];
    _effect = me?.equipped['nameeffect'];
    _colors = me != null && me.nameColors.isNotEmpty
        ? <String>[...me.nameColors]
        : List<String>.of(kChatFluxDefaultNameColors);
    while (_colors.length < 2) {
      _colors.add(kChatFluxDefaultNameColors[_colors.length]);
    }
  }

  bool get _dirty {
    final ChatFluxMe? me = _store.me.value;
    final List<String> savedColors = me != null && me.nameColors.isNotEmpty
        ? me.nameColors
        : kChatFluxDefaultNameColors;
    return _font != me?.equipped['namefont'] ||
        _effect != me?.equipped['nameeffect'] ||
        _colors.take(savedColors.length).join() != savedColors.join();
  }

  Future<void> _save({bool reset = false}) async {
    final String? token = ref.read(fluxerAuthTokenProvider);
    if (token == null) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _store.saveNameStyle(
        token,
        font: reset ? null : _font,
        effect: reset ? null : _effect,
        colors: reset ? null : _colors.take(2).toList(),
      );
      if (mounted) {
        setState(() {
          _reloadFromMe();
          _saved = !reset;
        });
      }
    } on ChatFluxShopException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.code == 'not_owned'
              ? chatFluxTr(
                  context,
                  'Ezt még nem vetted meg.',
                  "You don't own this yet.",
                )
              : chatFluxTr(
                  context,
                  'Nem sikerült menteni. Próbáld újra.',
                  'Could not save. Try again.',
                ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  bool _owns(ChatFluxItem item) => _store.owns(item);

  void _pick(ChatFluxItem? item, {required bool font}) {
    if (item != null && !_owns(item)) {
      widget.onOpenItem(item);
      return;
    }
    setState(() {
      _saved = false;
      if (font) {
        _font = item?.sku;
      } else {
        _effect = item?.sku;
      }
    });
  }

  Future<void> _customColor(int index) async {
    final String? picked = await showDialog<String>(
      context: context,
      builder: (BuildContext _) =>
          _ColorPickerDialog(initial: chatFluxParseHex(_colors[index])),
    );
    if (picked != null && mounted) {
      setState(() {
        _saved = false;
        _colors[index] = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ChatFluxCatalog? catalog = _store.catalog.value;
    final List<ChatFluxItem> fonts =
        catalog?.items
            .where((ChatFluxItem i) => i.type == 'namefont')
            .toList() ??
        const <ChatFluxItem>[];
    final List<ChatFluxItem> effects =
        catalog?.items
            .where((ChatFluxItem i) => i.type == 'nameeffect')
            .toList() ??
        const <ChatFluxItem>[];
    final bool ownsAny = <ChatFluxItem>[...fonts, ...effects].any(_owns);
    final ChatFluxRender? fontRender = _font == null
        ? null
        : catalog?.item(_font!)?.render;
    final ChatFluxRender? effectRender = _effect == null
        ? null
        : catalog?.item(_effect!)?.render;
    final String effectId = effectRender?.effect ?? 'solid';
    final bool twoColors = kChatFluxTwoColorEffects.contains(effectId);
    final List<String> colors = twoColors
        ? _colors.take(2).toList()
        : _colors.take(1).toList();
    ChatFluxNameStyle style(ChatFluxRender? f, ChatFluxRender? e) =>
        ChatFluxNameStyle.compose(f, e, colors);
    final bool hasWorn = _store.me.value?.wearing.nameStyle != null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      builder: (BuildContext context, ScrollController controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
        children: <Widget>[
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kTileBorder,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            chatFluxTr(
              context,
              'Névstílus módosítása',
              'Change Display Name Style',
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            chatFluxTr(
              context,
              'Ahogy itt kinéz, úgy látják a többiek a chatben, a taglistában és a profilodon.',
              'Others see it like this in chat, in the member list and on your profile.',
            ),
            style: const TextStyle(color: _kMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ChatFluxNameStylePreviewRow(
            name: widget.name,
            avatarUrl: widget.avatarUrl,
            nameStyle: style(fontRender, effectRender),
            large: true,
          ),
          _label(chatFluxTr(context, 'Betűtípus', 'Choose Font')),
          _tileGrid(
            columns: 4,
            children: <Widget>[
              _tile(
                selected: _font == null,
                locked: false,
                onTap: () => _pick(null, font: true),
                child: _sample('Gg', style(null, effectRender), 22),
              ),
              for (final ChatFluxItem item in fonts)
                _tile(
                  selected: _font == item.sku,
                  locked: !_owns(item),
                  onTap: () => _pick(item, font: true),
                  child: _sample('Gg', style(item.render, effectRender), 22),
                ),
            ],
          ),
          _label(chatFluxTr(context, 'Effekt', 'Choose Effect')),
          _tileGrid(
            columns: 3,
            children: <Widget>[
              _tile(
                selected: _effect == null,
                locked: false,
                onTap: () => _pick(null, font: false),
                child: _sample(
                  _effectLabel(context, 'solid'),
                  style(fontRender, null),
                  15,
                ),
              ),
              for (final ChatFluxItem item in effects)
                _tile(
                  selected: _effect == item.sku,
                  locked: !_owns(item),
                  onTap: () => _pick(item, font: false),
                  child: _sample(
                    _effectLabel(context, item.render.effect ?? ''),
                    style(fontRender, item.render),
                    15,
                  ),
                ),
            ],
          ),
          _label(chatFluxTr(context, 'Szín', 'Choose Colour')),
          if (twoColors)
            _subLabel(chatFluxTr(context, 'Első szín', 'First colour')),
          _colorRow(0),
          if (twoColors) ...<Widget>[
            const SizedBox(height: 10),
            _subLabel(chatFluxTr(context, 'Második szín', 'Second colour')),
            _colorRow(1),
          ],
          const SizedBox(height: 20),
          if (!ownsAny)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                chatFluxTr(
                  context,
                  'Vegyél egy betűtípust vagy effektet a boltban, és utána a színt is szabadon választhatod.',
                  'Buy a font or an effect in the shop, then you can pick the colour freely too.',
                ),
                style: const TextStyle(color: _kMuted, fontSize: 13),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFFCA5A5)),
              ),
            ),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _kBrand,
                    minimumSize: const Size.fromHeight(46),
                  ),
                  onPressed: !ownsAny || !_dirty || _saving
                      ? null
                      : () => unawaited(_save()),
                  child: Text(
                    _saved && !_dirty
                        ? chatFluxTr(context, 'Elmentve', 'Saved')
                        : chatFluxTr(context, 'Mentés', 'Save'),
                  ),
                ),
              ),
              if (hasWorn) ...<Widget>[
                const SizedBox(width: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 46),
                    side: const BorderSide(color: _kTileBorder),
                  ),
                  onPressed: _saving
                      ? null
                      : () => unawaited(_save(reset: true)),
                  child: Text(chatFluxTr(context, 'Alaphelyzet', 'Reset')),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _subLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        color: _kMuted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _sample(String text, ChatFluxNameStyle style, double size) => Center(
    child: ChatFluxNameText(
      text: text,
      nameStyle: style,
      maxLines: 1,
      overflow: TextOverflow.fade,
      style: TextStyle(
        color: Colors.white,
        fontSize: size,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _tileGrid({required int columns, required List<Widget> children}) =>
      LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          const double gap = 8;
          final double width =
              (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: <Widget>[
              for (final Widget child in children)
                SizedBox(width: width, height: 58, child: child),
            ],
          );
        },
      );

  Widget _tile({
    required bool selected,
    required bool locked,
    required VoidCallback onTap,
    required Widget child,
  }) => Material(
    color: _kTile,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(
        color: selected ? _kBrand : _kTileBorder,
        width: selected ? 2 : 1,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Opacity(opacity: locked ? 0.5 : 1, child: child),
            ),
          ),
          if (locked)
            const Positioned(
              top: 5,
              right: 5,
              child: Icon(Icons.lock_rounded, size: 12, color: _kMuted),
            ),
        ],
      ),
    ),
  );

  Widget _colorRow(int index) {
    final String value = _colors[index].toLowerCase();
    final bool custom = !kChatFluxNameColorPresets.contains(value);
    Widget swatch({
      required Color color,
      required bool selected,
      required VoidCallback onTap,
      Widget? icon,
    }) => GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: icon == null
            ? null
            : Center(
                child: IconTheme(
                  data: const IconThemeData(
                    size: 16,
                    color: Colors.white,
                    shadows: <Shadow>[
                      Shadow(blurRadius: 3, color: Color(0xCC000000)),
                    ],
                  ),
                  child: icon,
                ),
              ),
      ),
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        swatch(
          color: chatFluxParseHex(value) ?? _kBrand,
          selected: custom,
          onTap: () => unawaited(_customColor(index)),
          icon: const Icon(Icons.colorize_rounded),
        ),
        for (final String preset in kChatFluxNameColorPresets)
          swatch(
            color: chatFluxParseHex(preset)!,
            selected: value == preset,
            onTap: () => setState(() {
              _saved = false;
              _colors[index] = preset;
            }),
            icon: value == preset ? const Icon(Icons.check_rounded) : null,
          ),
      ],
    );
  }
}

/// Small HSL colour picker (hue, saturation, lightness sliders).
class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({this.initial});

  final Color? initial;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSLColor _hsl = HSLColor.fromColor(
    widget.initial ?? const Color(0xFFC084FC),
  );

  Widget _slider({
    required String label,
    required double value,
    required double max,
    required List<Color> track,
    required ValueChanged<double> onChanged,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(label, style: const TextStyle(color: _kMuted, fontSize: 12)),
      const SizedBox(height: 4),
      Container(
        height: 14,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          gradient: LinearGradient(colors: track),
        ),
      ),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 0,
          activeTrackColor: Colors.transparent,
          inactiveTrackColor: Colors.transparent,
          thumbColor: Colors.white,
          overlayShape: SliderComponentShape.noOverlay,
        ),
        child: Slider(value: value, max: max, onChanged: onChanged),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final Color color = _hsl.toColor();
    return AlertDialog(
      backgroundColor: _kSheet,
      title: Text(
        chatFluxTr(context, 'Saját szín', 'Custom colour'),
        style: const TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                chatFluxToHex(color).toUpperCase(),
                style: TextStyle(
                  color: _hsl.lightness > 0.6 ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _slider(
              label: chatFluxTr(context, 'Árnyalat', 'Hue'),
              value: _hsl.hue,
              max: 360,
              track: <Color>[
                for (int h = 0; h <= 360; h += 60)
                  HSLColor.fromAHSL(1, h.toDouble() % 360, 1, 0.5).toColor(),
              ],
              onChanged: (double v) => setState(() => _hsl = _hsl.withHue(v)),
            ),
            _slider(
              label: chatFluxTr(context, 'Telítettség', 'Saturation'),
              value: _hsl.saturation,
              max: 1,
              track: <Color>[
                _hsl.withSaturation(0).toColor(),
                _hsl.withSaturation(1).toColor(),
              ],
              onChanged: (double v) =>
                  setState(() => _hsl = _hsl.withSaturation(v)),
            ),
            _slider(
              label: chatFluxTr(context, 'Világosság', 'Lightness'),
              value: _hsl.lightness,
              max: 1,
              track: <Color>[
                Colors.black,
                _hsl.withLightness(0.5).toColor(),
                Colors.white,
              ],
              onChanged: (double v) =>
                  setState(() => _hsl = _hsl.withLightness(v)),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            chatFluxTr(context, 'Mégse', 'Cancel'),
            style: const TextStyle(color: _kMuted),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _kBrand),
          onPressed: () => Navigator.of(context).pop(chatFluxToHex(color)),
          child: Text(chatFluxTr(context, 'Kész', 'Done')),
        ),
      ],
    );
  }
}
