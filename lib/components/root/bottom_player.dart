import 'dart:ui';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:spotube/collections/assets.gen.dart';
import 'package:spotube/collections/spotube_icons.dart';
import 'package:spotube/components/player/player_actions.dart';
import 'package:spotube/components/player/player_overlay.dart';
import 'package:spotube/components/player/player_track_details.dart';
import 'package:spotube/components/player/player_controls.dart';
import 'package:spotube/components/player/volume_slider.dart';
import 'package:spotube/extensions/constrains.dart';
import 'package:spotube/extensions/context.dart';
import 'package:spotube/extensions/image.dart';
import 'package:spotube/models/logger.dart';
import 'package:flutter/material.dart';
import 'package:spotube/provider/authentication_provider.dart';
import 'package:spotube/provider/proxy_playlist/proxy_playlist_provider.dart';
import 'package:spotube/provider/user_preferences/user_preferences_provider.dart';
import 'package:spotube/provider/user_preferences/user_preferences_state.dart';
import 'package:spotube/provider/volume_provider.dart';
import 'package:spotube/utils/platform.dart';
import 'package:window_manager/window_manager.dart';

class BottomPlayer extends HookConsumerWidget {
  BottomPlayer({super.key});

  final logger = getLogger(BottomPlayer);
  @override
  Widget build(BuildContext context, ref) {
    final auth = ref.watch(authenticationProvider);
    final playlist = ref.watch(proxyPlaylistProvider);
    final layoutMode =
        ref.watch(userPreferencesProvider.select((s) => s.layoutMode));

    final mediaQuery = MediaQuery.of(context);

    String albumArt = useMemoized(
      () => playlist.activeTrack?.album?.images?.isNotEmpty == true
          ? (playlist.activeTrack?.album?.images).asUrlString(
              index: (playlist.activeTrack?.album?.images?.length ?? 1) - 1,
              placeholder: ImagePlaceholder.albumArt,
            )
          : Assets.albumPlaceholder.path,
      [playlist.activeTrack?.album?.images],
    );

    final theme = Theme.of(context);

    // returning an empty non spacious Container as the overlay will take
    // place in the global overlay stack aka [_entries]
    if (layoutMode == LayoutMode.compact ||
        ((mediaQuery.mdAndDown) && layoutMode == LayoutMode.adaptive)) {
      return PlayerOverlay(albumArt: albumArt);
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer.withOpacity(.8),
          ),
          child: Material(
            type: MaterialType.transparency,
            textStyle: theme.textTheme.bodyMedium!,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: PlayerTrackDetails(track: playlist.activeTrack),
                ),
                // controls
                Flexible(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: PlayerControls(),
                  ),
                ),
                // add to saved tracks
                Column(
                  children: [
                    PlayerActions(
                      extraActions: [
                        if (auth != null)
                          IconButton(
                            tooltip: context.l10n.mini_player,
                            icon: const Icon(SpotubeIcons.miniPlayer),
                            onPressed: () async {
                              if (!kIsDesktop) return;

                              final prevSize = await windowManager.getSize();
                              await windowManager.setMinimumSize(
                                const Size(300, 300),
                              );
                              await windowManager.setAlwaysOnTop(true);
                              if (!kIsLinux) {
                                await windowManager.setHasShadow(false);
                              }
                              await windowManager
                                  .setAlignment(Alignment.topRight);
                              await windowManager.setSize(const Size(400, 500));
                              await Future.delayed(
                                const Duration(milliseconds: 100),
                                () async {
                                  GoRouter.of(context).go(
                                    '/mini-player',
                                    extra: prevSize,
                                  );
                                },
                              );
                            },
                          ),
                      ],
                    ),
                    Container(
                      height: 40,
                      constraints: const BoxConstraints(maxWidth: 250),
                      padding: const EdgeInsets.only(right: 10),
                      child: Consumer(builder: (context, ref, _) {
                        final volume = ref.watch(volumeProvider);
                        return VolumeSlider(
                          fullWidth: true,
                          value: volume,
                          onChanged: (value) {
                            ref.read(volumeProvider.notifier).setVolume(value);
                          },
                        );
                      }),
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
