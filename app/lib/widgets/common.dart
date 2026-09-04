// Shared chrome components, ported from the design prototype's CSS classes
// (.card, .tag, .ns-listrow, .ns-header, .ns-tabbar, .seg) into Flutter
// widgets with the same names/roles.

import 'package:flutter/material.dart';

import '../theme.dart';

/// Sticky top bar with a leading slot (back button or brand mark), a
/// title, and an optional trailing action - mirrors `.ns-header`.
class NsHeader extends StatelessWidget implements PreferredSizeWidget {
  final Widget? leading;
  final String title;
  final Widget? trailing;

  const NsHeader({super.key, this.leading, required this.title, this.trailing});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      padding: const EdgeInsets.symmetric(horizontal: NetraSpace.s4),
      decoration: const BoxDecoration(
        color: NetraColors.bg,
        border: Border(bottom: BorderSide(color: NetraColors.divider, width: 2)),
      ),
      child: Row(
        children: [
          ?leading,
          if (leading != null) const SizedBox(width: NetraSpace.s3),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class NsBackButton extends StatelessWidget {
  final VoidCallback onPressed;
  const NsBackButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: NetraColors.bgMuted,
        shape: const CircleBorder(),
      ),
    );
  }
}

class NsBrandMark extends StatelessWidget {
  final String letter;
  final double size;
  const NsBrandMark({super.key, required this.letter, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: NetraColors.red600),
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.45,
        ),
      ),
    );
  }
}

/// Scrollable content area with standard padding - mirrors `.ns-body`.
class NsBody extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const NsBody({super.key, required this.child, this.padding = const EdgeInsets.all(NetraSpace.s4)});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SingleChildScrollView(padding: padding, child: child),
    );
  }
}

enum NsTagStyle { accent, outline, neutral }

/// Small pill/badge - mirrors `.tag` / `.tag-accent` / `.tag-outline` /
/// `.tag-neutral`.
class NsTag extends StatelessWidget {
  final String label;
  final NsTagStyle style;
  const NsTag(this.label, {super.key, this.style = NsTagStyle.neutral});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Color border;
    switch (style) {
      case NsTagStyle.accent:
        bg = NetraColors.red600;
        fg = Colors.white;
        border = NetraColors.red600;
      case NsTagStyle.outline:
        bg = Colors.transparent;
        fg = NetraColors.ink;
        border = NetraColors.dividerStrong;
      case NsTagStyle.neutral:
        bg = NetraColors.bgMuted;
        fg = NetraColors.inkMuted;
        border = NetraColors.divider;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 1.5),
        borderRadius: BorderRadius.circular(NetraRadius.pill),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// A tappable list row with a title/subtitle and optional trailing widget -
/// mirrors `.ns-listrow`.
class NsListRow extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool showDivider;

  const NsListRow({super.key, required this.child, this.onTap, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: NetraSpace.s3),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(bottom: BorderSide(color: NetraColors.divider, width: 2))
              : null,
        ),
        child: Row(children: [Expanded(child: child)]),
      ),
    );
  }
}

/// Flat bordered card - mirrors `.card` (+ `.card-title` / `.card-body`).
class NsCard extends StatelessWidget {
  final Widget child;
  final Color? accentBorder;
  final VoidCallback? onTap;

  const NsCard({super.key, required this.child, this.accentBorder, this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(NetraSpace.s4),
      decoration: BoxDecoration(
        color: NetraColors.bg,
        borderRadius: BorderRadius.circular(NetraRadius.card),
        border: Border(
          top: const BorderSide(color: NetraColors.divider, width: 2),
          right: const BorderSide(color: NetraColors.divider, width: 2),
          bottom: const BorderSide(color: NetraColors.divider, width: 2),
          left: BorderSide(color: accentBorder ?? NetraColors.divider, width: accentBorder != null ? 4 : 2),
        ),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(onTap: onTap, child: card);
  }
}

/// Two-way (EN/HI) segmented control - mirrors `.seg` / `.seg-opt`.
class NsSegControl extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const NsSegControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: NetraColors.dividerStrong, width: 2),
        borderRadius: BorderRadius.circular(NetraRadius.card),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            InkWell(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: i == selectedIndex ? NetraColors.red600 : Colors.transparent,
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: i == selectedIndex ? Colors.white : NetraColors.ink,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class NsSectionLabel extends StatelessWidget {
  final String text;
  const NsSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NetraSpace.s2),
      child: Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
