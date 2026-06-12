import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/admin_service.dart';
import '../widgets/user_list_tile.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final _svc = AdminService();
  final _searchCtrl = TextEditingController();

  List<dynamic> _users = [];
  int _total = 0;
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  String? _roleFilter;
  bool? _blockedFilter;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    if (reset) {
      _page = 1;
      _users = [];
      _hasMore = true;
    }
    if (!_hasMore) return;
    setState(() => _loading = true);
    try {
      final data = await _svc.getUsers(
        page: _page,
        limit: 20,
        role: _roleFilter,
        isBlocked: _blockedFilter,
        search: _searchCtrl.text.trim(),
      );
      final items = data['items'] as List<dynamic>? ?? [];
      final total = data['total'] as int? ?? 0;
      setState(() {
        _users = reset ? items : [..._users, ...items];
        _total = total;
        _hasMore = _users.length < total;
        _page++;
      });
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setRoleFilter(String? role) {
    _roleFilter = role;
    _blockedFilter = null;
    _load(reset: true);
  }

  void _setBlockedFilter() {
    _roleFilter = null;
    _blockedFilter = true;
    _load(reset: true);
  }

  void _clearFilters() {
    _roleFilter = null;
    _blockedFilter = null;
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchAndFilter(),
        Text(
          '$_total users found',
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: RefreshIndicator(
            color: const Color(0xFF4F46E5),
            onRefresh: () => _load(reset: true),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: _users.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _users.length) {
                  _load();
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF4F46E5), strokeWidth: 2),
                    ),
                  );
                }
                return UserListTile(
                  user: _users[index] as Map<String, dynamic>,
                  onTap: () => _showUserDetail(_users[index] as Map<String, dynamic>),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => Future.delayed(
              const Duration(milliseconds: 400),
              () => _load(reset: true),
            ),
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('All', _roleFilter == null && _blockedFilter == null,
                    _clearFilters),
                const SizedBox(width: 8),
                _filterChip('Students', _roleFilter == 'student',
                    () => _setRoleFilter('student')),
                const SizedBox(width: 8),
                _filterChip('Doctors', _roleFilter == 'doctor',
                    () => _setRoleFilter('doctor')),
                const SizedBox(width: 8),
                _filterChip('Blocked', _blockedFilter == true, _setBlockedFilter,
                    color: const Color(0xFFEF4444)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
    String label,
    bool selected,
    VoidCallback onTap, {
    Color color = const Color(0xFF4F46E5),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  void _showUserDetail(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _UserDetailSheet(
        user: user,
        svc: _svc,
        onChanged: () => _load(reset: true),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// User Detail Bottom Sheet
// ---------------------------------------------------------------------------

class _UserDetailSheet extends StatefulWidget {
  const _UserDetailSheet({
    required this.user,
    required this.svc,
    required this.onChanged,
  });

  final Map<String, dynamic> user;
  final AdminService svc;
  final VoidCallback onChanged;

  @override
  State<_UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends State<_UserDetailSheet> {
  bool _busy = false;
  String? _error;

  String get _name {
    final fn = widget.user['full_name'] as String?;
    return (fn != null && fn.isNotEmpty) ? fn : widget.user['email'] as String? ?? '';
  }

  bool get _isBlocked => widget.user['is_blocked'] as bool? ?? false;

  Future<void> _action(Future<void> Function() fn, String success) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await fn();
      if (mounted) Navigator.of(context).pop();
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success), backgroundColor: const Color(0xFF10B981)),
        );
      }
    } on AdminException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _confirmBlock() {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block User', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: reasonCtrl,
          decoration: InputDecoration(
            hintText: 'Reason for blocking...',
            hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () {
              Navigator.pop(ctx);
              _action(
                () => widget.svc.blockUser(widget.user['id'] as int, reasonCtrl.text),
                'User blocked.',
              );
            },
            child: const Text('Block', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmWarn() {
    final msgCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Send Warning', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: msgCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Warning message...',
            hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
            onPressed: () {
              Navigator.pop(ctx);
              _action(
                () => widget.svc.warnUser(widget.user['id'] as int, msgCtrl.text),
                'Warning sent.',
              );
            },
            child: const Text('Send', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _name,
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              widget.user['email'] as String? ?? '',
              style: GoogleFonts.inter(color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 4),
            Text(
              'Role: ${widget.user['role']}  •  '
              'Status: ${_isBlocked ? 'Blocked' : 'Active'}',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFEF4444))),
            ],
            const SizedBox(height: 24),
            if (_busy)
              const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
            else
              Column(
                children: [
                  _actionButton(
                    icon: Icons.warning_amber_rounded,
                    label: 'Send Warning',
                    color: const Color(0xFFF59E0B),
                    onTap: _confirmWarn,
                  ),
                  const SizedBox(height: 10),
                  if (_isBlocked)
                    _actionButton(
                      icon: Icons.check_circle_outline,
                      label: 'Unblock User',
                      color: const Color(0xFF10B981),
                      onTap: () => _action(
                        () => widget.svc.unblockUser(widget.user['id'] as int),
                        'User unblocked.',
                      ),
                    )
                  else
                    _actionButton(
                      icon: Icons.block,
                      label: 'Block User',
                      color: const Color(0xFFEF4444),
                      onTap: _confirmBlock,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: Icon(icon, color: color, size: 20),
        label: Text(label, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w600)),
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
