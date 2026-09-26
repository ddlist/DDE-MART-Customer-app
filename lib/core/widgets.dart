// DDE-Mart customer app — shared display widgets (original).
//
// Image handling with loading + fallback states, price display with
// discount strikethrough, and section headers. Used across home, catalog,
// orders and verticals so every screen looks like one app.

import 'package:flutter/material.dart';

import 'api_client.dart';

/// Network image that never leaves a hole: shimmer-grey while loading,
/// branded icon tile when the URL is missing or fails.
class ApiImage extends StatelessWidget {
  const ApiImage({
    super.key,
    required this.path,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
    this.icon = Icons.image_outlined,
  });

  final String? path;
  final double? height;
  final double? width;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final url = resolveAsset(path);
    final placeholder = Container(
      height: height,
      width: width,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        icon,
        size: 32,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );

    if (url == null) return ClipRRect(borderRadius: borderRadius, child: placeholder);

    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        url,
        height: height,
        width: width,
        fit: fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            height: height,
            width: width,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }
}

/// Selling price with an optional struck-through list price.
class PriceText extends StatelessWidget {
  const PriceText({
    super.key,
    required this.price,
    this.was,
    this.style,
  });

  final double price;
  final double? was;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.titleMedium;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          price.toStringAsFixed(2),
          style: base?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (was != null && was! > price) ...[
          const SizedBox(width: 6),
          Text(
            was!.toStringAsFixed(2),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  decoration: TextDecoration.lineThrough,
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ],
    );
  }
}

/// Rounded "-x%" / "SALE" badge for image overlays.
class DiscountBadge extends StatelessWidget {
  const DiscountBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onError,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

/// "Title … See all" row heading used by every rail on home.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
  });

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (onSeeAll != null)
            TextButton(onPressed: onSeeAll, child: const Text('See all')),
        ],
      ),
    );
  }
}

/// Standard empty + error states so screens never render blank.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.icon = Icons.inbox_outlined});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(apiMessage(error), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
