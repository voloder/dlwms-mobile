import 'package:dlwms_mobile/provider/auth_provider.dart';
import 'package:dlwms_mobile/provider/notification_provider.dart';
import 'package:dlwms_mobile/provider/theme_provider.dart';
import 'package:dlwms_mobile/services/background_service.dart';
import 'package:dlwms_mobile/services/check_status.dart';
import 'package:dlwms_mobile/theme/app_theme.dart';
import 'package:dlwms_mobile/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Postavke')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: const [
          _AccountCard(),
          SectionHeader('Izgled'),
          _AppearanceCard(),
          SectionHeader('Obavijesti'),
          _NotificationsCard(),
          SizedBox(height: 24),
          _AboutFooter(),
        ],
      ),
    );
  }
}

/// Rounded group of settings rows.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final scheme = Theme.of(context).colorScheme;
    final username = auth.username ?? 'Student';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        color: scheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                child: Text(
                  username.isEmpty ? '?' : username.substring(0, 1),
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                    ),
                    Text(
                      'DLWMS · Fakultet informacijskih tehnologija',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onPrimaryContainer
                                .withValues(alpha: 0.8),
                          ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _confirmLogout(context, auth),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Odjava'),
                style: TextButton.styleFrom(
                    foregroundColor: scheme.onPrimaryContainer),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, AuthProvider auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.logout_rounded),
        title: const Text('Odjava'),
        content: const Text(
            'Odjaviti se? Provjera obavijesti u pozadini će se zaustaviti.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Odjavi se'),
          ),
        ],
      ),
    );
    if (confirmed == true) await auth.logout();
  }
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final text = Theme.of(context).textTheme;
    final usingDevice = theme.useDeviceColors && theme.deviceColorsAvailable;

    return _Group(
      children: [
        const _ThemePreview(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Tema', style: text.titleSmall),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('Sistem'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Svijetla'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Tamna'),
                ),
              ],
              selected: {theme.themeMode},
              onSelectionChanged: (value) => theme.setThemeMode(value.first),
            ),
          ),
        ),
        if (theme.deviceColorsAvailable)
          SwitchListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
            title: const Text('Boje uređaja'),
            subtitle: const Text('Prema pozadini telefona (Material You).'),
            value: theme.useDeviceColors,
            onChanged: theme.setUseDeviceColors,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Text('Boja', style: text.titleSmall),
        ),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: usingDevice ? 0.4 : 1,
          child: IgnorePointer(
            ignoring: usingDevice,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final preset in ThemeProvider.presets)
                    _Swatch(
                      color: preset.color,
                      tooltip: preset.name,
                      selected: !usingDevice &&
                          theme.seedColor.toARGB32() ==
                              preset.color.toARGB32(),
                      onTap: () => theme.setSeedColor(preset.color),
                    ),
                  _CustomSwatch(theme: theme, disabled: usingDevice),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 12),
      ],
    );
  }
}

/// Miniature of the app in the current colours.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget dot(Color color) => Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.medium - 4),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.small + 2),
            ),
            child: Icon(Icons.campaign_outlined,
                color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pregled teme', style: text.titleSmall),
                const SizedBox(height: 6),
                Row(children: [
                  dot(scheme.primary),
                  dot(scheme.secondary),
                  dot(scheme.tertiary),
                  dot(scheme.surfaceContainerHigh),
                ]),
              ],
            ),
          ),
          FilledButton.tonal(onPressed: () {}, child: const Text('Dugme')),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? scheme.onSurface : Colors.transparent,
              width: 2,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                : null,
          ),
        ),
      ),
    );
  }
}

/// Opens a hue/lightness picker for a colour of the user's own.
class _CustomSwatch extends StatelessWidget {
  const _CustomSwatch({required this.theme, required this.disabled});

  final ThemeProvider theme;
  final bool disabled;

  bool get _isCustom => !ThemeProvider.presets
      .any((p) => p.color.toARGB32() == theme.seedColor.toARGB32());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = !disabled && _isCustom;

    return Tooltip(
      message: 'Prilagođena boja',
      child: InkResponse(
        radius: 26,
        onTap: () async {
          final color = await showDialog<Color>(
            context: context,
            builder: (_) => _ColorPickerDialog(initial: theme.seedColor),
          );
          if (color != null) await theme.setSeedColor(color);
        },
        child: Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? scheme.onSurface : Colors.transparent,
              width: 2,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? theme.seedColor : null,
              gradient: selected
                  ? null
                  : const SweepGradient(colors: [
                      Color(0xFFE53935),
                      Color(0xFFFDD835),
                      Color(0xFF43A047),
                      Color(0xFF1E88E5),
                      Color(0xFF8E24AA),
                      Color(0xFFE53935),
                    ]),
            ),
            child: Icon(
              selected ? Icons.check_rounded : Icons.add_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial});

  final Color initial;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSLColor _hsl = HSLColor.fromColor(widget.initial);

  @override
  Widget build(BuildContext context) {
    final color = _hsl.withLightness(0.45).toColor();
    final preview = ColorScheme.fromSeed(
      seedColor: color,
      brightness: Theme.of(context).brightness,
    );

    Widget slider(String label, double value, double max,
            ValueChanged<double> onChanged, List<Color> track) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            Container(
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                gradient: LinearGradient(colors: track),
              ),
            ),
            Slider(value: value, max: max, onChanged: onChanged),
          ],
        );

    return AlertDialog(
      title: const Text('Prilagođena boja'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                for (final c in [
                  preview.primary,
                  preview.primaryContainer,
                  preview.secondary,
                  preview.tertiary,
                ])
                  Expanded(
                    child: Container(
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            slider(
              'Nijansa',
              _hsl.hue,
              360,
              (v) => setState(() => _hsl = _hsl.withHue(v)),
              [
                for (var h = 0; h <= 360; h += 60)
                  HSLColor.fromAHSL(1, h.toDouble(), 0.8, 0.5).toColor(),
              ],
            ),
            slider(
              'Zasićenost',
              _hsl.saturation,
              1,
              (v) => setState(() => _hsl = _hsl.withSaturation(v)),
              [_hsl.withSaturation(0).toColor(), _hsl.withSaturation(1).toColor()],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(_hsl.withLightness(0.45).toColor()),
          child: const Text('Primijeni'),
        ),
      ],
    );
  }
}

class _PaletteStyleTile extends StatelessWidget {
  const _PaletteStyleTile({
    required this.style,
    required this.selected,
    required this.scheme,
    required this.onTap,
  });

  final PaletteStyle style;
  final bool selected;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = Theme.of(context).colorScheme;

    return Tooltip(
      message: style.description,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 104,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(
              color: selected ? current.primary : current.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 26,
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: ColoredBox(color: scheme.primary)),
                      Expanded(child: ColoredBox(color: scheme.secondary)),
                      Expanded(child: ColoredBox(color: scheme.tertiary)),
                    ],
                  ),
                ),
              ),
              Text(
                style.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSurface,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationsCard extends StatelessWidget {
  const _NotificationsCard();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final notifications = context.watch<NotificationProvider>();
    final theme = Theme.of(context);
    final muted =
        theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline);

    return _Group(
      children: [
        SwitchListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 0),
          secondary: const Icon(Icons.notifications_active_outlined),
          title: const Text('Provjera obavijesti u pozadini'),
          subtitle: Text(_backgroundDescription(auth)),
          value: BackgroundService.isSupported && auth.backgroundCheckEnabled,
          onChanged: BackgroundService.isSupported
              ? auth.setBackgroundCheckEnabled
              : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(72, 0, 16, 10),
          child: Row(
            children: [
              Icon(Icons.history_rounded,
                  size: 14, color: theme.colorScheme.outline),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_lastCheckText(notifications.lastCheck),
                    style: muted),
              ),
            ],
          ),
        ),
        const Divider(indent: 16, endIndent: 16),
        SwitchListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
          secondary: const Icon(Icons.filter_alt_outlined),
          title: const Text('Prikaži samo relevantne obavijesti'),
          subtitle: const Text(
            'Predmeti tvoje godine studija i oni bez ocjene. '
            'Opće obavijesti se uvijek prikazuju.',
          ),
          value: notifications.relevantOnly,
          onChanged: notifications.setRelevantOnly,
        ),
        if (notifications.relevantOnly)
          _RelevantSubjects(provider: notifications),
      ],
    );
  }

  static String _backgroundDescription(AuthProvider auth) {
    if (!BackgroundService.isSupported) {
      return 'Svakih 5 minuta dok je aplikacija otvorena.';
    }
    if (auth.backgroundCheckEnabled && !auth.backgroundRunning) {
      return 'Nije pokrenuta. Provjeri dozvolu za obavještenja.';
    }
    return 'Svakih 5 minuta, i kad je aplikacija zatvorena.';
  }

  static String _lastCheckText(CheckStatus? status) {
    if (status == null) return 'Zadnja provjera: još nije bilo provjere.';

    final now = DateTime.now();
    final sameDay = status.time.year == now.year &&
        status.time.month == now.month &&
        status.time.day == now.day;
    final when =
        DateFormat(sameDay ? 'HH:mm' : 'dd.MM. HH:mm').format(status.time);

    final result = switch (status.result) {
      CheckResult.ok => status.newCount == 0
          ? 'nema novih obavijesti'
          : 'novih obavijesti: ${status.newCount}',
      CheckResult.authFailed => 'prijava nije uspjela, otvorite aplikaciju',
      CheckResult.error => 'nije uspjela, pokušava ponovo za 5 minuta',
    };
    return 'Zadnja provjera u $when · $result';
  }
}

/// Chips with the subjects that currently count as relevant.
class _RelevantSubjects extends StatelessWidget {
  const _RelevantSubjects({required this.provider});

  final NotificationProvider provider;

  @override
  Widget build(BuildContext context) {
    final subjects = provider.relevantSubjects;
    final loading = provider.loadingRelevantSubjects;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(72, 0, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subjects == null
                      ? 'Relevantni predmeti'
                      : 'Relevantni predmeti (${subjects.length})',
                  style: theme.textTheme.labelLarge,
                ),
              ),
              loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Osvježi listu predmeta',
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      onPressed: () =>
                          provider.refreshRelevantSubjects(force: true),
                    ),
            ],
          ),
          if (subjects == null || subjects.isEmpty)
            Text(
              loading
                  ? 'Učitavam predmete...'
                  : 'Nije učitana – prikazuju se sve obavijesti.',
              style: theme.textTheme.bodySmall,
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final subject in subjects)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: Text(
                      subject,
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AboutFooter extends StatelessWidget {
  const _AboutFooter();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.outline);
    return Column(
      children: [
        Text('DLWMS Mobile', style: style?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text('Neslužbena aplikacija, nije povezana s FIT-om.', style: style),
      ],
    );
  }
}
