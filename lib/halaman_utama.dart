import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'features/transaksi/halaman_pos.dart';
import 'features/stok/halaman_stok.dart';
import 'features/laporan/halaman_laporan.dart';
import 'features/aktivitas/halaman_aktivitas_sistem.dart';
import 'features/users/halaman_user.dart';

import 'database/services/firestore_service.dart';
import 'database/services/auth_activity_service.dart';
import 'database/models/transaksi_model.dart';
import 'database/models/produk_model.dart';
import 'core/theme_controller.dart';
import 'core/ui/interactive_widgets.dart';
import 'core/ui/app_feedback.dart';
import 'core/access/role_access.dart';

LinearGradient _pageGradient(bool isDark) => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? const [
              Color(0xFF141414),
              Color(0xFF101010),
              Color(0xFF0B0B0B),
            ]
          : const [
              Color(0xFFF7F6F3),
              Color(0xFFF0EEE9),
              Color(0xFFFFFFFF),
            ],
    );

LinearGradient _sidebarGradient(bool isDark) => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? const [
              Color(0xFF181818),
              Color(0xFF0F0F0F),
            ]
          : const [
              Color(0xFFF6F4F0),
              Color(0xFFEDE9E2),
            ],
    );

Color _dashSurface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF232323)
        : const Color(0xFFFFFFFF);

Color _dashSurfaceAlt(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2B2B2B)
        : const Color(0xFFF1EFEB);

Color _dashBorder(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF343434)
        : const Color(0xFFD7D3C9);

Color _dashText(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFF4EDE2)
        : const Color(0xFF1C1B1A);

Color _dashMuted(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB2B2B2)
        : const Color(0xFF7C776D);

const _dashAccent = Color(0xFFF28C28);
const _mobileBreakpoint = 720.0;

enum _PageKey {
  pos,
  dashboard,
  stok,
  laporan,
  aktivitas,
  users,
}

class HalamanUtama extends StatefulWidget {
  final String role;

  const HalamanUtama({super.key, required this.role});

  @override
  State<HalamanUtama> createState() => _HalamanUtamaState();
}

class _HalamanUtamaState extends State<HalamanUtama> {
  int halamanAktif = 0;
  final firestore = FirestoreService();
  bool _migrasiDiproses = false;
  List<_NavItem> _cachedNavItems = const [];

  Map<String, Map<String, bool>> _resolveAccess(
    Map<String, dynamic>? config,
    Map<String, dynamic>? profile,
  ) {
    final merged = mergeRoleAccessConfig(config);
    final base = merged[widget.role] ?? kDefaultRoleAccess[widget.role]!;
    final override = profile?['access_override'];
    return applyAccessOverride(
      base,
      override is Map<String, dynamic> ? override : null,
    );
  }

  List<_NavItem> _navItemsFor(Map<String, Map<String, bool>> access) {
    final pages = access['pages'] ?? {};
    final items = <_NavItem>[];
    if (pages['dashboard'] == true) {
      items.add(const _NavItem(
        page: _PageKey.dashboard,
        icon: Icons.space_dashboard_outlined,
        label: 'Dashboard',
      ));
    }
    if (pages['transaksi'] == true) {
      items.add(const _NavItem(
        page: _PageKey.pos,
        icon: Icons.point_of_sale,
        label: 'Transaksi',
      ));
    }
    if (pages['stok'] == true) {
      items.add(const _NavItem(
        page: _PageKey.stok,
        icon: Icons.inventory_2_outlined,
        label: 'Manajemen Stok',
      ));
    }
    if (pages['laporan'] == true) {
      items.add(const _NavItem(
        page: _PageKey.laporan,
        icon: Icons.description_outlined,
        label: 'Laporan',
      ));
    }
    if (pages['aktivitas'] == true) {
      items.add(const _NavItem(
        page: _PageKey.aktivitas,
        icon: Icons.event_note_outlined,
        label: 'Aktivitas Sistem',
      ));
    }
    if (pages['users'] == true) {
      items.add(const _NavItem(
        page: _PageKey.users,
        icon: Icons.manage_accounts_outlined,
        label: 'Users',
      ));
    }
    return items;
  }

  final Map<_PageKey, _HeaderInfo> _headerInfo = const {
    _PageKey.pos: _HeaderInfo(
      title: 'Transaksi',
      subtitle: 'Mode transaksi cepat',
    ),
    _PageKey.dashboard: _HeaderInfo(
      title: 'Dashboard',
      subtitle: 'Ringkasan performa operasional',
    ),
    _PageKey.stok: _HeaderInfo(
      title: 'Manajemen Stok',
      subtitle: 'Kelola stok, harga, dan status produk',
    ),
    _PageKey.laporan: _HeaderInfo(
      title: 'Laporan',
      subtitle: 'Ringkasan performa dan detail transaksi',
    ),
    _PageKey.aktivitas: _HeaderInfo(
      title: 'Aktivitas Sistem',
      subtitle: 'Catatan aktivitas pengguna dan sistem',
    ),
    _PageKey.users: _HeaderInfo(
      title: 'Users',
      subtitle: 'Kelola akun dan peran pengguna',
    ),
  };

  Widget _isiHalaman(
    Map<String, Map<String, bool>> access,
    List<_NavItem> items,
  ) {
    final page = items[halamanAktif].page;
    final features = access['features'] ?? {};
    switch (page) {
      case _PageKey.pos:
        return const HalamanPOS();
      case _PageKey.dashboard:
        return _dashboard();
      case _PageKey.stok:
        return HalamanStok(
          canAdd: features['stok_tambah'] == true,
          canEdit: features['stok_edit'] == true,
          canDelete: features['stok_hapus'] == true,
        );
      case _PageKey.laporan:
        return const HalamanLaporan();
      case _PageKey.aktivitas:
        return const HalamanAktivitasSistem();
      case _PageKey.users:
        return HalamanUser(
          canCreate: features['users_create'] == true,
          canEdit: features['users_edit'] == true,
          canDelete: features['users_hapus'] == true,
          canEditRoleDefaults: widget.role == 'admin',
        );
    }
  }

  @override
  void initState() {
    super.initState();
    _jalankanMigrasiTransaksiItems();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppFeedback.flushQueued(context);
    });
  }

  void _jalankanMigrasiTransaksiItems() {
    if (_migrasiDiproses) return;
    _migrasiDiproses = true;

    Future(() async {
      try {
        await firestore.migrasiTransaksiItems();
      } catch (_) {}
    });
  }

  void _openPage(_PageKey key) {
    final index = _cachedNavItems.indexWhere((item) => item.page == key);
    if (index == -1) return;
    setState(() => halamanAktif = index);
  }

  Future<void> _logout() async {
    await AuthActivityService.instance.signOutWithActivity(source: 'manual');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<Map<String, dynamic>?>(
      stream: user == null
          ? const Stream<Map<String, dynamic>?>.empty()
          : firestore.streamUserProfile(user.uid, email: user.email),
      builder: (context, profileSnap) {
        return StreamBuilder<Map<String, dynamic>?>(
          stream: firestore.streamRoleAccessConfig(),
          builder: (context, accessSnap) {
            final access = _resolveAccess(accessSnap.data, profileSnap.data);
            final items = _navItemsFor(access);
            _cachedNavItems = items;
            if (items.isEmpty) {
              return const Center(child: Text('Akses tidak tersedia.'));
            }
            if (halamanAktif >= items.length) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => halamanAktif = 0);
                }
              });
            }
            final activePage = items[halamanAktif].page;
            final header =
                _headerInfo[activePage] ?? _headerInfo[_PageKey.pos]!;
            return LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < _mobileBreakpoint;

                if (isMobile) {
                  return Scaffold(
                    appBar: AppBar(
                      title: Text(header.title),
                      backgroundColor: _dashSurface(context),
                      foregroundColor: _dashText(context),
                      elevation: 0,
                      actions: [
                        IconButton(
                          tooltip: 'Tema',
                          onPressed: () => ThemeController.toggle(context),
                          icon: Icon(
                            Theme.of(context).brightness == Brightness.dark
                                ? Icons.dark_mode
                                : Icons.light_mode,
                            color: _dashAccent,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Logout',
                          onPressed: () async {
                            await _logout();
                          },
                          icon: const Icon(Icons.logout, color: _dashAccent),
                        ),
                      ],
                    ),
                    body: Container(
                      decoration: BoxDecoration(
                        gradient: _pageGradient(isDark),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                header.subtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _dashMuted(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(child: _isiHalaman(access, items)),
                        ],
                      ),
                    ),
                    bottomNavigationBar: BottomNavigationBar(
                      currentIndex: halamanAktif,
                      onTap: (index) => setState(() => halamanAktif = index),
                      type: BottomNavigationBarType.fixed,
                      selectedItemColor: _dashAccent,
                      unselectedItemColor: _dashMuted(context),
                      items: [
                        for (final item in items)
                          BottomNavigationBarItem(
                            icon: Icon(item.icon),
                            label: item.label,
                          ),
                      ],
                    ),
                  );
                }

                return Scaffold(
                  body: Row(
                    children: [
                      _Sidebar(
                        items: items,
                        selectedIndex: halamanAktif,
                        onSelected: (index) {
                          setState(() => halamanAktif = index);
                        },
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            _TopBar(
                              title: header.title,
                              subtitle: header.subtitle,
                            ),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: _pageGradient(isDark),
                                ),
                                child: _isiHalaman(access, items),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // =============================
  // DASHBOARD
  // =============================
  Widget _dashboard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;
        const gap = 16.0;

        return StreamBuilder<DateTime?>(
          stream: firestore.streamDashboardResetAt(),
          builder: (context, snapshot) {
            final resetAt = snapshot.data;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _SummaryRow(
                    firestore: firestore,
                    resetAt: resetAt,
                  ),
                  const SizedBox(height: gap),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _RekapStokCard(resetAt: resetAt),
                        ),
                        const SizedBox(width: gap),
                        Expanded(
                          flex: 2,
                          child: _TransaksiTerbaruCard(
                            firestore: firestore,
                            onOpenLaporan: () => _openPage(_PageKey.laporan),
                            resetAt: resetAt,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _RekapStokCard(resetAt: resetAt),
                        const SizedBox(height: gap),
                        _TransaksiTerbaruCard(
                          firestore: firestore,
                          onOpenLaporan: () => _openPage(_PageKey.laporan),
                          resetAt: resetAt,
                        ),
                      ],
                    ),
                  const SizedBox(height: gap),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _LowStockCard(
                            firestore: firestore,
                            onOpenStok: () => _openPage(_PageKey.stok),
                          ),
                        ),
                        const SizedBox(width: gap),
                        Expanded(
                          flex: 2,
                          child: _PenjualanChartCard(
                            firestore: firestore,
                            resetAt: resetAt,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _LowStockCard(
                          firestore: firestore,
                          onOpenStok: () => _openPage(_PageKey.stok),
                        ),
                        const SizedBox(height: gap),
                        _PenjualanChartCard(
                          firestore: firestore,
                          resetAt: resetAt,
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _NavItem {
  final _PageKey page;
  final IconData icon;
  final String label;

  const _NavItem({
    required this.page,
    required this.icon,
    required this.label,
  });
}

class _HeaderInfo {
  final String title;
  final String subtitle;

  const _HeaderInfo({required this.title, required this.subtitle});
}

class _Sidebar extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _Sidebar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final border = _dashBorder(context);
    final text = _dashText(context);
    final muted = _dashMuted(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemBgSelected =
        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF6F1E8);
    final itemBg = isDark ? const Color(0xFF242424) : const Color(0xFFF9F6F0);
    final iconBgSelected =
        isDark ? const Color(0xFF3A3222) : const Color(0xFFF3E7C8);
    return Container(
      width: 220,
      decoration: BoxDecoration(
        gradient: _sidebarGradient(isDark),
        border: Border(
          right: BorderSide(color: border),
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Image.asset(
              'image/nira_posbaru.png',
              width: 160,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                final selected = index == selectedIndex;

                return InkWell(
                  onTap: () => onSelected(index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? itemBgSelected : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected ? border : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 34,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: selected ? _dashAccent : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: selected ? iconBgSelected : itemBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? _dashAccent : border,
                            ),
                          ),
                          child: Icon(
                            item.icon,
                            color: selected ? _dashAccent : muted,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              color: selected ? text : muted,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _TopBar extends StatefulWidget {
  final String title;
  final String subtitle;

  const _TopBar({
    required this.title,
    required this.subtitle,
  });

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  late DateTime _now;
  Timer? _timer;
  final FirestoreService _firestore = FirestoreService();

  Future<void> _logout() async {
    await AuthActivityService.instance.signOutWithActivity(source: 'manual');
  }

  Stream<User?> _authStream() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return Stream<User?>.periodic(
        const Duration(seconds: 2),
        (_) => FirebaseAuth.instance.currentUser,
      ).distinct((a, b) => a?.uid == b?.uid);
    }
    return FirebaseAuth.instance.authStateChanges();
  }

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDateTime(DateTime dateTime) {
    const hari = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const bulan = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final dayName = hari[dateTime.weekday - 1];
    final monthName = bulan[dateTime.month - 1];
    final hour = dateTime.hour;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$dayName, ${dateTime.day} $monthName ${dateTime.year} - '
        '${hour12.toString().padLeft(2, '0')}:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final surface = _dashSurface(context);
    final surfaceAlt = _dashSurfaceAlt(context);
    final border = _dashBorder(context);
    final text = _dashText(context);
    final muted = _dashMuted(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        color: surface,
        border: Border(
          bottom: BorderSide(color: border),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 760;
          final titleSection = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  color: text,
                  fontSize: isCompact ? 16 : 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (widget.subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    widget.subtitle,
                    style: TextStyle(
                      color: muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          );

          Widget buildUserChip(String label) {
            if (isCompact) {
              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: text,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              );
            }

            return HoverButton(
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: _dashAccent,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: _dashAccent),
                  ),
                ),
                child: Text(label.toUpperCase()),
              ),
            );
          }

          final userChip = StreamBuilder<User?>(
            stream: _authStream(),
            builder: (context, snapshot) {
              final user = snapshot.data;
              if (user == null) {
                return buildUserChip('User');
              }
              return StreamBuilder<Map<String, dynamic>?>(
                stream: _firestore.streamUserProfile(
                  user.uid,
                  email: user.email,
                ),
                builder: (context, profileSnap) {
                  final profile = profileSnap.data;
                  final nickname =
                      (profile?['nama_panggilan'] ?? '').toString().trim();
                  final name = user.displayName;
                  final email = user.email ?? '';
                  final label = nickname.isNotEmpty
                      ? nickname
                      : (name != null && name.trim().isNotEmpty)
                          ? name.trim()
                          : (email.isNotEmpty
                              ? email.split('@').first
                              : 'User');
                  return buildUserChip(label);
                },
              );
            },
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: titleSection),
                    const SizedBox(width: 12),
                    userChip,
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Logout',
                      onPressed: () async {
                        await _logout();
                      },
                      icon: const Icon(Icons.logout, color: _dashAccent),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () => ThemeController.toggle(context),
                      icon: Icon(
                        Theme.of(context).brightness == Brightness.dark
                            ? Icons.dark_mode
                            : Icons.light_mode,
                        color: _dashAccent,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          _formatDateTime(_now),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: muted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: titleSection),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  userChip,
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Logout',
                        onPressed: () async {
                          await _logout();
                        },
                        icon: const Icon(Icons.logout, color: _dashAccent),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: () => ThemeController.toggle(context),
                        icon: Icon(
                          Theme.of(context).brightness == Brightness.dark
                              ? Icons.dark_mode
                              : Icons.light_mode,
                          color: _dashAccent,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatDateTime(_now),
                        style: TextStyle(
                          fontSize: 12,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _SummaryRange { bulanan, tahunan }

class _SummaryRow extends StatefulWidget {
  final FirestoreService firestore;
  final DateTime? resetAt;

  const _SummaryRow({
    required this.firestore,
    this.resetAt,
  });

  @override
  State<_SummaryRow> createState() => _SummaryRowState();
}

class _SummaryRowState extends State<_SummaryRow> {
  _SummaryRange _range = _SummaryRange.bulanan;
  late int _tahun;
  late int _bulan;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _tahun = now.year;
    _bulan = now.month;
  }

  DateTimeRange _currentRange() {
    if (_range == _SummaryRange.tahunan) {
      final start = DateTime(_tahun, 1, 1);
      final end = DateTime(_tahun + 1, 1, 1);
      return DateTimeRange(start: start, end: end);
    }
    final start = DateTime(_tahun, _bulan, 1);
    final end = DateTime(_tahun, _bulan + 1, 1);
    return DateTimeRange(start: start, end: end);
  }

  String _formatResetDate(DateTime date) {
    const bulan = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final day = date.day.toString().padLeft(2, '0');
    final month = bulan[date.month - 1];
    return '$day $month ${date.year}';
  }

  Future<void> _showMonthMenu(BuildContext context, List<String> labels) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final box = context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<int>(
      context: context,
      position: position,
      items: [
        PopupMenuItem<int>(
          padding: EdgeInsets.zero,
          child: _MonthGridMenu(
            labels: labels,
            selected: _bulan,
            onSelected: (value) => Navigator.pop(context, value),
          ),
        ),
      ],
    );
    if (selected != null && mounted) {
      setState(() => _bulan = selected);
    }
  }

  Future<void> _showYearMenu(
    BuildContext context,
    List<int> years,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final box = context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<int>(
      context: context,
      position: position,
      items: [
        PopupMenuItem<int>(
          padding: EdgeInsets.zero,
          child: _YearGridMenu(
            years: years,
            selected: _tahun,
            onSelected: (value) => Navigator.pop(context, value),
          ),
        ),
      ],
    );
    if (selected != null && mounted) {
      setState(() => _tahun = selected);
    }
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset dashboard?'),
          content: const Text(
            'Anda yakin ingin merestart? '
            'Dashboard akan menghitung ulang mulai hari ini. '
            'Data laporan lama tetap tersedia.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _dashAccent,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    await widget.firestore.setDashboardResetNow();
    if (!mounted) return;
    AppFeedback.show(
      context,
      message: 'Dashboard direset mulai hari ini',
      type: AppFeedbackType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        const bulanLabels = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'Mei',
          'Jun',
          'Jul',
          'Agu',
          'Sep',
          'Okt',
          'Nov',
          'Des',
        ];
        return StreamBuilder<List<Transaksi>>(
          stream: widget.firestore.streamSemuaTransaksi(),
          builder: (_, snap) {
            final list = snap.data ?? const <Transaksi>[];
            final filteredForYear = widget.resetAt == null
                ? list
                : list
                    .where((t) => !t.tanggal.isBefore(widget.resetAt!))
                    .toList();
            final years = filteredForYear
                .map((t) => t.tanggal.year)
                .toSet()
                .toList()
              ..sort((a, b) => b.compareTo(a));
            final yearOptions =
                years.isNotEmpty ? years : <int>[DateTime.now().year];
            if (!yearOptions.contains(_tahun)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _tahun = yearOptions.first);
                }
              });
            }
            final range = _currentRange();
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final pillBg =
                isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF5F1EA);
            final filterBar = Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _dashBorder(context)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PeriodPill(
                        label: 'Bulanan',
                        active: _range == _SummaryRange.bulanan,
                        onTap: () => setState(
                          () => _range = _SummaryRange.bulanan,
                        ),
                      ),
                      _PeriodPill(
                        label: 'Tahunan',
                        active: _range == _SummaryRange.tahunan,
                        onTap: () => setState(
                          () => _range = _SummaryRange.tahunan,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_range == _SummaryRange.bulanan)
                  _SelectChip(
                    icon: Icons.calendar_month_outlined,
                    label: bulanLabels[_bulan - 1],
                    child: Builder(
                      builder: (context) => InkWell(
                        onTap: () => _showMonthMenu(context, bulanLabels),
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                          child: Icon(Icons.expand_more),
                        ),
                      ),
                    ),
                  ),
                _SelectChip(
                  icon: Icons.event_outlined,
                  label: '$_tahun',
                  child: Builder(
                    builder: (context) => InkWell(
                      onTap: () => _showYearMenu(context, yearOptions),
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                        child: Icon(Icons.expand_more),
                      ),
                    ),
                  ),
                ),
                if (widget.resetAt != null)
                  Text(
                    'Reset: ${_formatResetDate(widget.resetAt!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _dashMuted(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            );
            final restartButton = OutlinedButton.icon(
              onPressed: _confirmReset,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Restart'),
            );
            final filtered = list.where((t) {
              final dt = t.tanggal;
              final start =
                  widget.resetAt != null && widget.resetAt!.isAfter(range.start)
                      ? widget.resetAt!
                      : range.start;
              return !dt.isBefore(start) && dt.isBefore(range.end);
            }).toList();
            final totalTransaksi = filtered.length;
            var totalPenjualan = 0;
            var totalLaba = 0;
            for (final t in filtered) {
              totalLaba += t.total;
              for (final item in t.items) {
                final qtyRaw = item['qty'];
                if (qtyRaw is int) {
                  totalPenjualan += qtyRaw;
                } else if (qtyRaw is num) {
                  totalPenjualan += qtyRaw.round();
                }
              }
            }

            final cards = [
              _SummaryCard(
                icon: Icons.payments,
                label: 'Total Transaksi',
                value: totalTransaksi.toString(),
                accent: const Color(0xFFF28C28),
              ),
              _SummaryCard(
                icon: Icons.trending_up,
                label: 'Total Penjualan',
                value: totalPenjualan.toString(),
                accent: const Color(0xFFC76A1F),
              ),
              _SummaryCard(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Total Laba',
                value: '+ Rp $totalLaba',
                accent: const Color(0xFFE7A354),
              ),
            ];

            if (isWide) {
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: filterBar),
                      restartButton,
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 16),
                      Expanded(child: cards[1]),
                      const SizedBox(width: 16),
                      Expanded(child: cards[2]),
                    ],
                  ),
                ],
              );
            }

            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: filterBar),
                    restartButton,
                  ],
                ),
                const SizedBox(height: 16),
                cards[0],
                const SizedBox(height: 16),
                cards[1],
                const SizedBox(height: 16),
                cards[2],
              ],
            );
          },
        );
      },
    );
  }
}

class _PeriodPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _PeriodPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = active ? Colors.black : _dashText(context);
    final bgColor = active ? _dashAccent : Colors.transparent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _SelectChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;

  const _SelectChip({
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _dashSurfaceAlt(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _dashBorder(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _dashMuted(context)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _dashText(context),
            ),
          ),
          const SizedBox(width: 6),
          child,
        ],
      ),
    );
  }
}

class _MonthGridMenu extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  const _MonthGridMenu({
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = _dashText(context);
    final muted = _dashMuted(context);
    const columns = 6;
    const chipWidth = 32.0;
    const spacing = 6.0;
    final gridWidth = (chipWidth * columns) + (spacing * (columns - 1));
    return SizedBox(
      width: gridWidth,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Wrap(
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < labels.length; i++)
              SizedBox(
                width: chipWidth,
                child: InkWell(
                  onTap: () => onSelected(i + 1),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i + 1 == selected
                          ? _dashAccent.withValues(alpha: 0.18)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: i + 1 == selected
                            ? _dashAccent.withValues(alpha: 0.35)
                            : _dashBorder(context),
                      ),
                    ),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: i + 1 == selected ? textColor : muted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _YearGridMenu extends StatelessWidget {
  final List<int> years;
  final int selected;
  final ValueChanged<int> onSelected;

  const _YearGridMenu({
    required this.years,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = _dashText(context);
    final muted = _dashMuted(context);
    if (years.length == 1) {
      final year = years.first;
      return SizedBox(
        width: 112,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Center(
            child: SizedBox(
              width: 72,
              child: InkWell(
                onTap: () => onSelected(year),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: year == selected
                        ? _dashAccent.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: year == selected
                          ? _dashAccent.withValues(alpha: 0.35)
                          : _dashBorder(context),
                    ),
                  ),
                  child: Text(
                    '$year',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: year == selected ? textColor : muted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final crossAxis = years.length < 6 ? years.length : 6;
    final chipWidth = 38.0;
    final spacing = 5.0;
    final gridWidth = (chipWidth * crossAxis) + (spacing * (crossAxis - 1));
    return SizedBox(
      width: gridWidth,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: GridView.count(
          crossAxisCount: crossAxis,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.4,
          children: [
            for (final year in years)
              InkWell(
                onTap: () => onSelected(year),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: year == selected
                        ? _dashAccent.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: year == selected
                          ? _dashAccent.withValues(alpha: 0.35)
                          : _dashBorder(context),
                    ),
                  ),
                  child: Text(
                    '$year',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: year == selected ? textColor : muted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final valueColor =
        value.trim().startsWith('+') ? accent : _dashText(context);
    return HoverCard(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _panelDecoration(context),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: _dashMuted(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: valueColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RekapStokCard extends StatefulWidget {
  final DateTime? resetAt;

  const _RekapStokCard({this.resetAt});

  @override
  State<_RekapStokCard> createState() => _RekapStokCardState();
}

enum _RekapRange { hari, bulan, tahun }

class _RekapStokCardState extends State<_RekapStokCard> {
  _RekapRange _range = _RekapRange.hari;
  final FirestoreService firestore = FirestoreService();

  String _formatRange(DateTime now, _RekapRange range) {
    const bulan = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final monthName = bulan[now.month - 1];
    if (range == _RekapRange.hari) {
      return '${now.day} $monthName ${now.year}';
    }
    if (range == _RekapRange.tahun) {
      return 'Jan - Des ${now.year}';
    }
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    return '01 - ${lastDay.toString().padLeft(2, '0')} $monthName ${now.year}';
  }

  String _monthShort(int month) {
    const bulan = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return bulan[month - 1];
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<_SalesChartPoint> _buildChartData(
    List<Transaksi> transaksi,
    _RekapRange range,
    DateTime now,
  ) {
    const bucketCount = 3;
    if (range == _RekapRange.hari) {
      final points = <_SalesChartPoint>[];
      for (var i = bucketCount - 1; i >= 0; i--) {
        final start = DateTime(now.year, now.month, now.day, now.hour - i);
        final end = start.add(const Duration(hours: 1));
        final count = transaksi.where((t) {
          final waktu = t.tanggal;
          return waktu.isAtSameMomentAs(start) ||
              (waktu.isAfter(start) && waktu.isBefore(end));
        }).length;
        final label = '${start.hour.toString().padLeft(2, '0')}.00';
        points.add(_SalesChartPoint(label: label, transaksi: count));
      }
      return points;
    }

    if (range == _RekapRange.tahun) {
      final points = <_SalesChartPoint>[];
      for (var i = bucketCount - 1; i >= 0; i--) {
        final monthDate = DateTime(now.year, now.month - i, 1);
        final count = transaksi.where((t) {
          return t.tanggal.year == monthDate.year &&
              t.tanggal.month == monthDate.month;
        }).length;
        points.add(
          _SalesChartPoint(
            label: _monthShort(monthDate.month),
            transaksi: count,
          ),
        );
      }
      return points;
    }

    final points = <_SalesChartPoint>[];
    for (var i = bucketCount - 1; i >= 0; i--) {
      final dayDate = now.subtract(Duration(days: i));
      final count =
          transaksi.where((t) => _isSameDay(t.tanggal, dayDate)).length;
      points.add(
        _SalesChartPoint(
          label: '${dayDate.day} ${_monthShort(dayDate.month)}',
          transaksi: count,
        ),
      );
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final rangeLabel = _formatRange(now, _range);

    return HoverCard(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _panelDecoration(context),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 720;
            final chips = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RangeChip(
                  label: 'Hari ini',
                  selected: _range == _RekapRange.hari,
                  onTap: () => setState(() => _range = _RekapRange.hari),
                ),
                _RangeChip(
                  label: 'Bulan ini',
                  selected: _range == _RekapRange.bulan,
                  onTap: () => setState(() => _range = _RekapRange.bulan),
                ),
                _RangeChip(
                  label: 'Tahun ini',
                  selected: _range == _RekapRange.tahun,
                  onTap: () => setState(() => _range = _RekapRange.tahun),
                ),
              ],
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isNarrow) ...[
                  const Text(
                    'Rekap Transaksi',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(rangeLabel, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 12),
                  chips,
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Rekap Transaksi',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(rangeLabel,
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      chips,
                    ],
                  ),
                const SizedBox(height: 16),
                StreamBuilder<List<Transaksi>>(
                  stream: firestore.streamSemuaTransaksi(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final data = snapshot.data ?? const <Transaksi>[];
                    final filtered = widget.resetAt == null
                        ? data
                        : data
                            .where((t) => !t.tanggal.isBefore(widget.resetAt!))
                            .toList();
                    final points = _buildChartData(filtered, _range, now);
                    return _StockChart(data: points);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SalesChartPoint {
  final String label;
  final int transaksi;

  const _SalesChartPoint({
    required this.label,
    required this.transaksi,
  });
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? scheme.primary : Theme.of(context).dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? scheme.primary : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _StockChart extends StatelessWidget {
  final List<_SalesChartPoint> data;

  const _StockChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (data.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF6F4EF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: const Text('Belum ada transaksi'),
      );
    }
    final maxValue =
        data.map((e) => e.transaksi).reduce((a, b) => a > b ? a : b);
    final chartHeight = 200.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF6F4EF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LegendDot(color: scheme.primary, label: 'Transaksi'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: chartHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.map((point) {
                final masukH = maxValue == 0
                    ? 0.0
                    : point.transaksi.toDouble() / maxValue.toDouble();
                return Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _Bar(
                              heightFactor: masukH,
                              color: scheme.primary,
                              maxHeight: chartHeight - 32,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        point.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double heightFactor;
  final double maxHeight;
  final Color color;

  const _Bar({
    required this.heightFactor,
    required this.maxHeight,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final height = maxHeight * heightFactor;
    return Container(
      width: 70,
      height: height < 2 ? 2 : height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, color: textColor)),
      ],
    );
  }
}

class _TransaksiTerbaruCard extends StatelessWidget {
  final FirestoreService firestore;
  final VoidCallback onOpenLaporan;
  final DateTime? resetAt;

  const _TransaksiTerbaruCard({
    required this.firestore,
    required this.onOpenLaporan,
    this.resetAt,
  });

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _panelDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onOpenLaporan,
              borderRadius: BorderRadius.circular(8),
              child: const Text(
                'Transaksi Terbaru',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<Transaksi>>(
              stream: firestore.streamSemuaTransaksi(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final data = snapshot.data!;
                final filtered = resetAt == null
                    ? data
                    : data.where((t) => !t.tanggal.isBefore(resetAt!)).toList();

                if (filtered.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Belum ada transaksi')),
                  );
                }

                return Column(
                  children: filtered.take(3).map((t) {
                    return _TransaksiItemTile(
                      nama: _formatInvoiceLabel(t.id, t.tanggal),
                      deskripsi: '${t.jenis} - ${t.items.length} item',
                      total: 'Rp ${t.total}',
                      waktu: _formatJam(t.tanggal),
                      qtyLabel: 'x${t.items.length}',
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: HoverButton(
                child: OutlinedButton(
                  onPressed: onOpenLaporan,
                  child: const Text('Lihat Semua'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransaksiItemTile extends StatelessWidget {
  final String nama;
  final String deskripsi;
  final String total;
  final String waktu;
  final String qtyLabel;

  const _TransaksiItemTile({
    required this.nama,
    required this.deskripsi,
    required this.total,
    required this.waktu,
    required this.qtyLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : const Color(0xFFF2F0EB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.receipt_long,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nama, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(deskripsi, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.local_fire_department,
                        size: 12, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(qtyLabel, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(total, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(waktu, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LowStockCard extends StatelessWidget {
  final FirestoreService firestore;
  final VoidCallback onOpenStok;

  const _LowStockCard({
    required this.firestore,
    required this.onOpenStok,
  });

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _panelDecoration(context),
        child: StreamBuilder<List<Produk>>(
          stream: firestore.ambilSemuaProduk(),
          builder: (context, snapshot) {
            final produk = snapshot.data ?? const <Produk>[];
            final lowCount = produk.where((p) => p.stok < 10).length;
            final hasLow = lowCount > 0;
            final scheme = Theme.of(context).colorScheme;
            final iconColor = hasLow
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: 0.5);
            return Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color:
                        scheme.primary.withValues(alpha: hasLow ? 0.12 : 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Icon(Icons.warning_amber_rounded, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Low Stock',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        hasLow
                            ? '$lowCount produk membutuhkan restock'
                            : 'Stok aman',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                HoverButton(
                  enabled: hasLow,
                  child: OutlinedButton(
                    onPressed: hasLow ? onOpenStok : null,
                    child: const Text('Cek'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PenjualanChartCard extends StatelessWidget {
  final FirestoreService firestore;
  final DateTime? resetAt;

  const _PenjualanChartCard({
    required this.firestore,
    this.resetAt,
  });

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _panelDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Penjualan 30 Hari Terakhir',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            _SalesLineChart(
              firestore: firestore,
              resetAt: resetAt,
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesLineChart extends StatelessWidget {
  final FirestoreService firestore;
  final DateTime? resetAt;

  const _SalesLineChart({
    required this.firestore,
    this.resetAt,
  });

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<List<Transaksi>>(
      stream: firestore.streamSemuaTransaksi(),
      builder: (context, snapshot) {
        final now = DateTime.now();
        final transaksiRaw = snapshot.data ?? const <Transaksi>[];
        final transaksi = resetAt == null
            ? transaksiRaw
            : transaksiRaw.where((t) => !t.tanggal.isBefore(resetAt!)).toList();
        final values = <int>[];
        var total = 0;
        for (var i = 29; i >= 0; i--) {
          final day = DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: i));
          final sum = transaksi
              .where((t) => _isSameDay(t.tanggal, day))
              .fold<int>(0, (s, t) => s + t.total);
          values.add(sum);
          total += sum;
        }

        return SizedBox(
          height: 160,
          child: CustomPaint(
            painter: _LineChartPainter(values: values, color: scheme.primary),
            child: Container(
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F0EB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              padding: const EdgeInsets.all(12),
              alignment: Alignment.bottomRight,
              child: Text(
                _formatRupiahSimple(total),
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<int> values;
  final Color color;

  _LineChartPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final safeHeight = size.height - 12;
    final maxValue =
        values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);
    final points = <Offset>[];
    final denom = values.length > 1 ? values.length - 1 : 1;
    for (var i = 0; i < values.length; i++) {
      final x = size.width * (i / denom);
      final ratio = maxValue == 0 ? 0.0 : values[i] / maxValue;
      final y = safeHeight - (safeHeight * ratio);
      points.add(Offset(x, y));
    }

    if (points.isEmpty) {
      return;
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

BoxDecoration _panelDecoration(BuildContext context) {
  return BoxDecoration(
    color: _dashSurface(context),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: _dashBorder(context)),
    boxShadow: [
      BoxShadow(
        color: const Color(0x66000000),
        blurRadius: 18,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

String _formatJam(DateTime tanggal) {
  final jam = tanggal.hour.toString().padLeft(2, '0');
  final menit = tanggal.minute.toString().padLeft(2, '0');
  return '$jam:$menit';
}

String _formatInvoiceLabel(String id, DateTime tanggal) {
  final date =
      '${tanggal.year}${tanggal.month.toString().padLeft(2, '0')}${tanggal.day.toString().padLeft(2, '0')}';
  final tail = id.length > 4 ? id.substring(id.length - 4) : id;
  return 'INV-$date-$tail';
}

String _formatRupiahSimple(int value) {
  final buffer = StringBuffer();
  final str = value.abs().toString();
  for (var i = 0; i < str.length; i++) {
    final pos = str.length - i;
    buffer.write(str[i]);
    if (pos > 1 && pos % 3 == 1) buffer.write('.');
  }
  final prefix = value < 0 ? '-Rp ' : 'Rp ';
  return '$prefix${buffer.toString()}';
}
