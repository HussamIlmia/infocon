import 'dart:async';
import 'package:flutter/material.dart';
import '../registration/cognito_service.dart';
import '../api_service.dart';

class DashboardLayout extends StatefulWidget {
  final Widget content;
  final String companyId;
  final bool showNotificationsInSidebar;
  final int selectedNavIndex;

  const DashboardLayout({
    super.key,
    required this.content,
    required this.companyId,
    this.showNotificationsInSidebar = true,
    this.selectedNavIndex = 0,
  });

  @override
  DashboardLayoutState createState() => DashboardLayoutState();
}

class DashboardLayoutState extends State<DashboardLayout> {
  final bool _isSidebarOpen = true;
  bool _isLoadingUnread = false;
  int _unreadCount = 0;
  Timer? _refreshTimer;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedNavIndex;
    _fetchUnreadCount();

    // Optional: refresh every 60 seconds:
    _refreshTimer = Timer.periodic(const Duration(seconds: 300), (_) {
      _fetchUnreadCount();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> refreshUnreadCount() async {
    await _fetchUnreadCount();
  }

  /// Actually fetch unread inquiries from backend
  Future<void> _fetchUnreadCount() async {
    if (!widget.showNotificationsInSidebar) return;
    setState(() => _isLoadingUnread = true);
    try {
      final inquiries = await ApiService.fetchInquiries(widget.companyId);
      final count = inquiries.where((inq) => !inq.isRead).length;
      setState(() {
        _unreadCount = count;
      });
    } catch (e) {
      debugPrint("Error fetching unread count: $e");
    } finally {
      setState(() => _isLoadingUnread = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    // Using Scaffold so InkWell in nav items has a Material ancestor
    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              if (!isMobile || _isSidebarOpen) _buildSidebar(isMobile),
              Expanded(child: widget.content),
            ],
          ),
          if (_isLoadingUnread)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildSidebar(bool isMobile) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),
          _buildProfileHeader(),
          Divider(color: Colors.grey.shade300),
          // Nav items:
          _buildNavItem(
            index: 0,
            icon: Icons.dashboard,
            label: '問い合わせ一覧',
            onTap: () {
              Navigator.pushReplacementNamed(
                context,
                '/console',
                arguments: {'companyId': widget.companyId},
              );
            },
            // Bubbles only on index=0
            notificationCount: widget.showNotificationsInSidebar ? _unreadCount : 0,
          ),
          _buildNavItem(
            index: 1,
            icon: Icons.person_add_alt_1,
            label: '作業員登録',
            onTap: () {
              Navigator.pushReplacementNamed(
                context,
                '/registerWorker',
                arguments: widget.companyId,
              );
            },
          ),
          _buildNavItem(
            index: 2,
            icon: Icons.description,
            label: '作業員生成書類',
            onTap: () {
              Navigator.pushReplacementNamed(
                context,
                '/workerDocument',
                arguments: widget.companyId,
              );
            },
          ),
          _buildNavItem(
            index: 3,
            icon: Icons.chat,
            label: 'チャットリンク管理',
            onTap: () {
              Navigator.pushReplacementNamed(
                context,
                '/ChatLinkManagement',
                arguments: widget.companyId,
              );
            },
          ),
          const Spacer(),
          _buildNavItem(
            index: 4,
            icon: Icons.logout,
            label: 'ログアウト',
            onTap: () {
              CognitoService.instance.signOut();
              Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary,
            ),
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Text(
              '管',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '管理者',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    int notificationCount = 0,
  }) {
    return _NavItem(
      index: index,
      icon: icon,
      label: label,
      isSelected: _selectedIndex == index,
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        onTap();
      },
      notificationCount: (index == 0) ? notificationCount : 0,
    );
  }
}

class _NavItem extends StatefulWidget {
  final int index;
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int notificationCount;

  const _NavItem({
    required this.index,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.notificationCount = 0,
  });

  @override
  __NavItemState createState() => __NavItemState();
}

class __NavItemState extends State<_NavItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedColor = colorScheme.primary.withValues(alpha: 0.2);
    final hoverColor = colorScheme.primary.withValues(alpha: 0.1);

    final backgroundColor = widget.isSelected
        ? selectedColor
        : (_isHovering ? hoverColor : Colors.transparent);

    final iconColor = widget.isSelected
        ? colorScheme.primary
        : (_isHovering ? colorScheme.primary : Colors.black54);

    final textColor = widget.isSelected
        ? colorScheme.primary
        : (_isHovering ? Colors.black87 : Colors.black87);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: InkWell(
        onTap: widget.onTap,
        splashColor: colorScheme.primary.withValues(alpha: 0.2),
        child: Container(
          color: backgroundColor,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Icon(widget.icon, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Text(widget.label, style: TextStyle(color: textColor, fontSize: 14)),
                    if (widget.index == 0 && widget.notificationCount > 0)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${widget.notificationCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
