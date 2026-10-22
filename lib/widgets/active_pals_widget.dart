import 'package:flutter/material.dart';
import '../services/presence_service.dart';

/// Reusable Active Pals widget for the Flutter mobile application.
///
/// Under the free Supabase tier, presence is DISABLED by default.
/// When disabled, this widget renders [SizedBox.shrink()] (completely hidden)
/// and initiates ZERO network requests or background polling.
///
/// To re-enable:
/// Build with `--dart-define PRESENCE_ENABLED=true`.
class ActivePalsWidget extends StatefulWidget {
  final Axis direction;

  const ActivePalsWidget({
    super.key,
    this.direction = Axis.horizontal,
  });

  @override
  State<ActivePalsWidget> createState() => _ActivePalsWidgetState();
}

class _ActivePalsWidgetState extends State<ActivePalsWidget> {
  final PresenceService _presenceService = PresenceService();
  List<Map<String, dynamic>> _onlineFriends = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (PresenceService.isPresenceEnabled) {
      _loadOnlineFriends();
    }
  }

  Future<void> _loadOnlineFriends() async {
    if (!PresenceService.isPresenceEnabled) return;

    setState(() => _isLoading = true);
    final friends = await _presenceService.fetchOnlineFriends();
    if (mounted) {
      setState(() {
        _onlineFriends = friends;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // When presence is disabled, completely hide Active Pals and online indicators
    if (!PresenceService.isPresenceEnabled) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_onlineFriends.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi, color: Colors.green, size: 16),
              const SizedBox(width: 6),
              const Text(
                'Active Pals',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_onlineFriends.length}',
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _onlineFriends.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final friend = _onlineFriends[index];
                return Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: friend['avatar_url'] != null
                              ? NetworkImage(friend['avatar_url'])
                              : null,
                          child: friend['avatar_url'] == null
                              ? Text(friend['username']?[0]?.toUpperCase() ?? 'U')
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      friend['username'] ?? '',
                      style: const TextStyle(fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
