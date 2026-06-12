import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/admin_service.dart';

class AdminActivityTab extends StatefulWidget {
  const AdminActivityTab({super.key});

  @override
  State<AdminActivityTab> createState() => _AdminActivityTabState();
}

class _AdminActivityTabState extends State<AdminActivityTab> {
  final _svc = AdminService();

  List<dynamic> _items = [];
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    if (reset) {
      _page = 1;
      _items = [];
      _hasMore = true;
    }
    if (!_hasMore) return;
    setState(() => _loading = true);
    try {
      final data = await _svc.getActivityLog(page: _page, limit: 30);
      final newItems = data['items'] as List<dynamic>? ?? [];
      final total = data['total'] as int? ?? 0;
      setState(() {
        _items = reset ? newItems : [..._items, ...newItems];
        _hasMore = _items.length < total;
        _page++;
      });
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
    }

    if (_items.isEmpty) {
      return Center(
        child: Text(
          'No admin activity yet.',
          style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF4F46E5),
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            _load();
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF4F46E5), strokeWidth: 2),
              ),
            );
          }
          return _ActivityItem(item: _items[index] as Map<String, dynamic>);
        },
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({required this.item});
  final Map<String, dynamic> item;

  String _formatTime(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminName = item['admin_name'] as String? ?? 'Admin';
    final action = item['action'] as String? ?? '';
    final timestamp = item['timestamp'] as String?;
    final targetUserId = item['target_user_id'] as int?;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.admin_panel_settings_outlined,
                    color: Color(0xFF4F46E5), size: 18),
              ),
              Container(
                width: 2,
                height: 32,
                color: const Color(0xFFE2E8F0),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        adminName,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatTime(timestamp),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    action,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  if (targetUserId != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'User #$targetUserId',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF4F46E5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
