import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../state/app_state.dart';

class OfflineStatusBanner extends StatefulWidget {
  const OfflineStatusBanner({super.key, required this.child});

  final Widget child;

  @override
  State<OfflineStatusBanner> createState() => _OfflineStatusBannerState();
}

class _OfflineStatusBannerState extends State<OfflineStatusBanner>
    with WidgetsBindingObserver {
  bool _online = true;
  bool _manualSyncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    ConnectivityService.instance.addListener(_onConnectivityChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _trySyncPending();
    }
  }

  void _onConnectivityChanged(bool online) {
    if (!mounted) return;
    setState(() => _online = online);
    if (online) _trySyncPending();
  }

  Future<void> _refresh() async {
    final online = await ConnectivityService.instance.isOnline();
    if (!mounted) return;
    setState(() => _online = online);
    if (online) _trySyncPending();
  }

  Future<void> _trySyncPending() async {
    if (!mounted || !_online) return;
    final appState = context.read<AppState>();
    if (appState.pendingSyncCount == 0 || appState.syncInProgress) return;

    SyncService.instance.scheduleSync(appState);
  }

  void _handleSyncResult(SyncResult result) {
    if (!mounted) return;

    if (result.syncedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.syncedCount == 1
                ? '1 assessment synced to server.'
                : '${result.syncedCount} assessments synced to server.',
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 4),
        ),
      );
    } else if (result.failedCount > 0 && result.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.lastError!),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () {
              final appState = context.read<AppState>();
              unawaited(
                SyncService.instance
                    .syncPendingAssessments(appState)
                    .then(_handleSyncResult),
              );
            },
          ),
        ),
      );
    }
  }

  Future<void> _retrySyncNow() async {
    if (!mounted || !_online) return;
    final appState = context.read<AppState>();
    if (appState.pendingSyncCount == 0 || appState.syncInProgress || _manualSyncing) {
      return;
    }

    setState(() => _manualSyncing = true);
    try {
      final result = await SyncService.instance.syncPendingAssessments(appState);
      _handleSyncResult(result);
    } finally {
      if (mounted) setState(() => _manualSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final pending = appState.pendingSyncCount;
    final syncing = appState.syncInProgress || _manualSyncing;
    final showBanner = !_online || pending > 0 || syncing;

    String bannerText;
    if (!_online) {
      bannerText = 'Offline mode — assessments are saved on this device.';
    } else if (syncing) {
      bannerText = appState.syncProgress ?? 'Syncing pending assessment(s)...';
    } else if (pending > 0) {
      bannerText = appState.lastSyncError != null
          ? '$pending pending — sync failed. Tap to retry.'
          : '$pending assessment(s) waiting to sync. Tap to retry.';
    } else {
      bannerText = '';
    }

    return Column(
      children: [
        if (showBanner)
          Material(
            color: !_online
                ? const Color(0xFFEF4444)
                : (appState.lastSyncError != null
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFF59E0B)),
            child: SafeArea(
              bottom: false,
              child: InkWell(
                onTap: _online && pending > 0 && !syncing ? _retrySyncNow : null,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (syncing) ...[
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          bannerText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
