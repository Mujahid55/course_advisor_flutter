import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UserListTile extends StatelessWidget {
  const UserListTile({
    super.key,
    required this.user,
    this.onTap,
  });

  final Map<String, dynamic> user;
  final VoidCallback? onTap;

  Color get _roleColor {
    switch (user['role'] as String?) {
      case 'it_admin':
        return const Color(0xFF7C3AED);
      case 'doctor':
        return const Color(0xFF0891B2);
      default:
        return const Color(0xFF4F46E5);
    }
  }

  String get _roleLabel {
    switch (user['role'] as String?) {
      case 'it_admin':
        return 'Admin';
      case 'doctor':
        return 'Doctor';
      default:
        return 'Student';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBlocked = user['is_blocked'] as bool? ?? false;
    final isActive = user['is_active'] as bool? ?? true;
    final fullName = user['full_name'] as String?;
    final email = user['email'] as String? ?? '';
    final displayName = (fullName != null && fullName.isNotEmpty) ? fullName : email;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isBlocked
                ? const Color(0xFFFEE2E2)
                : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _roleColor.withValues(alpha: 0.15),
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: GoogleFonts.inter(
                  color: _roleColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  if (fullName != null && fullName.isNotEmpty)
                    Text(
                      email,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _roleColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _roleLabel,
                    style: GoogleFonts.inter(
                      color: _roleColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isBlocked
                            ? const Color(0xFFEF4444)
                            : isActive
                                ? const Color(0xFF22C55E)
                                : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isBlocked ? 'Blocked' : (isActive ? 'Active' : 'Inactive'),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isBlocked
                            ? const Color(0xFFEF4444)
                            : isActive
                                ? const Color(0xFF22C55E)
                                : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
