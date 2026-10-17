import 'package:flutter/material.dart';

import '../data/grigri_store.dart';
import '../model/ad.dart';
import '../model/plan.dart' show MediaKind;
import '../theme.dart';
import 'ad_editor.dart';
import 'ad_region_picker.dart';
import 'common.dart';

/// The Ads tab (Premium; specs/ads.md): my ads, newest first, each with
/// where it is in review, and **New ad**. An approved ad shows between
/// plans on everyone's Discover while I'm Premium.
class AdsScreen extends StatelessWidget {
  const AdsScreen({super.key});

  Future<void> _newAd(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final sent = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const AdEditor()));
    if (sent == true) {
      messenger.showSnackBar(SnackBar(content: Text(l.adSent)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final ads = store.myAds;
    final premium = store.premium.active;
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.adsTitle),
        actions: [
          IconButton(
            tooltip: l.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: store.refreshMyAds,
          ),
        ],
      ),
      floatingActionButton: premium
          ? FloatingActionButton.extended(
              // Plans has one too, in the same tab stack: no hero.
              heroTag: null,
              icon: const Icon(Icons.add),
              label: Text(l.newAd),
              onPressed: () => _newAd(context),
            )
          : null,
      body: !store.isLoaded(Section.ads)
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: store.refreshMyAds,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                children: [
                  if (!premium)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        l.adsNeedPremium,
                        style: const TextStyle(color: Mountain.clay),
                      ),
                    ),
                  if (ads.isEmpty)
                    EmptyState(
                      icon: Icons.campaign_outlined,
                      title: l.adsEmptyTitle,
                      message: l.adsEmptyMessage,
                    )
                  else
                    for (final ad in ads) _MyAdTile(ad),
                ],
              ),
            ),
    );
  }
}

class _MyAdTile extends StatelessWidget {
  const _MyAdTile(this.ad);

  final Ad ad;

  Future<void> _delete(BuildContext context) async {
    final store = StoreScope.read(context);
    final l = context.l10n;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deleteAdQuestion),
        content: Text(l.deleteAdMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.delete, style: const TextStyle(color: Mountain.clay)),
          ),
        ],
      ),
    );
    if (sure == true) await store.deleteAd(ad.id);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Card(
      key: ValueKey('my ad ${ad.id}'),
      child: ListTile(
        leading: AdThumb(ad),
        title: Text(
          ad.text.isEmpty ? ad.site : ad.text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ad.site,
              style: const TextStyle(color: Mountain.sky),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              adWhere(context, ad),
              style: const TextStyle(color: Mountain.granite),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            AdStatusTag(ad.status),
          ],
        ),
        trailing: IconButton(
          tooltip: l.delete,
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _delete(context),
        ),
      ),
    );
  }
}

/// Where an ad is in review, as a tag.
class AdStatusTag extends StatelessWidget {
  const AdStatusTag(this.status, {super.key});

  final AdStatus status;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return switch (status) {
      AdStatus.pending => Tag(
        l.adStatusPending,
        icon: Icons.hourglass_top,
        color: Mountain.sand,
      ),
      AdStatus.approved => Tag(
        l.adStatusApproved,
        icon: Icons.check,
        color: Mountain.olive,
      ),
      AdStatus.rejected => Tag(
        l.adStatusRejected,
        icon: Icons.block,
        color: Mountain.clay,
      ),
    };
  }
}

/// A small square of an ad's photo (a video's or text-only ad's icon).
class AdThumb extends StatelessWidget {
  const AdThumb(this.ad, {super.key});

  final Ad ad;

  @override
  Widget build(BuildContext context) {
    final key = ad.mediaKey;
    final Widget child = key != null && ad.mediaKind == MediaKind.image
        ? Image(
            image: StoreScope.of(context).photo(key),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
          )
        : Icon(
            ad.mediaKind == MediaKind.video
                ? Icons.videocam_outlined
                : Icons.campaign_outlined,
            color: Mountain.sky,
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 52,
        height: 52,
        color: Mountain.surfaceHigh,
        child: child,
      ),
    );
  }
}
