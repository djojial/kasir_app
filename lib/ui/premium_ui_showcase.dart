
import 'package:flutter/material.dart';

const _pageGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFF7FAFF),
    Color(0xFFEAF2FF),
    Color(0xFFFFFFFF),
  ],
);

const _panelGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFFFFFFF),
    Color(0xFFF1F7FF),
  ],
);

const _panelBorder = Color(0xFFB7D6F6);
const _panelShadow = Color(0x220A3D7A);
const _primaryBlue = Color(0xFF2F80ED);
const _primaryDark = Color(0xFF0F2F50);
const _textMuted = Color(0xFF5B7AA1);

class PremiumUiShowcase extends StatelessWidget {
  const PremiumUiShowcase({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _pageGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1100;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TopHeader(isWide: isWide),
                    const SizedBox(height: 24),
                    _SectionTitle(
                      title: 'Ringkasan',
                      subtitle: 'Kinerja toko hari ini',
                      trailing: _GhostButton(
                        label: 'Export',
                        icon: Icons.file_download_outlined,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SummaryGrid(isWide: isWide),
                    const SizedBox(height: 28),
                    _SectionTitle(
                      title: 'POS Modern',
                      subtitle: 'Layout kasir premium',
                    ),
                    const SizedBox(height: 14),
                    _PosShowcase(isWide: isWide),
                    const SizedBox(height: 28),
                    _SectionTitle(
                      title: 'Manajemen Stok',
                      subtitle: 'Tabel stok rapi dan elegan',
                    ),
                    const SizedBox(height: 14),
                    _InventoryTable(isWide: isWide),
                    const SizedBox(height: 28),
                    _SectionTitle(
                      title: 'Laporan',
                      subtitle: 'Ringkasan dan detail transaksi',
                    ),
                    const SizedBox(height: 14),
                    _ReportSection(isWide: isWide),
                    const SizedBox(height: 28),
                    _SectionTitle(
                      title: 'Login',
                      subtitle: 'Kartu masuk dengan aura premium',
                    ),
                    const SizedBox(height: 14),
                    _LoginShowcase(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  final bool isWide;

  const _TopHeader({required this.isWide});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE8F1FF),
                  Color(0xFFD9E9FF),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _panelBorder),
            ),
            child: const Icon(Icons.storefront, color: _primaryBlue, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Atelier Retail POS',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _primaryDark,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Experience dashboard, POS, inventory, and reports in one flow.',
                  style: TextStyle(color: _textMuted),
                ),
              ],
            ),
          ),
          if (isWide) ...[
            const _PillInfo(
              icon: Icons.timer_outlined,
              label: 'Open',
              value: '10:49 AM',
            ),
            const SizedBox(width: 12),
          ],
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.local_fire_department),
            label: const Text('Upgrade'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final bool isWide;

  const _SummaryGrid({required this.isWide});

  @override
  Widget build(BuildContext context) {
    final cards = [
      const _SummaryCard(
        title: 'Pendapatan',
        value: 'Rp 12.450.000',
        delta: '+8.4%',
        color: Color(0xFF2F80ED),
        icon: Icons.trending_up,
      ),
      const _SummaryCard(
        title: 'Transaksi',
        value: '482',
        delta: '+3.1%',
        color: Color(0xFF14B8A6),
        icon: Icons.receipt_long,
      ),
      const _SummaryCard(
        title: 'Item Terjual',
        value: '1.240',
        delta: '+5.9%',
        color: Color(0xFF1FB6FF),
        icon: Icons.inventory_2_outlined,
      ),
      const _SummaryCard(
        title: 'Top Kasir',
        value: 'Wahyu',
        delta: '98% CSAT',
        color: Color(0xFF6366F1),
        icon: Icons.star_outline,
      ),
    ];

    if (isWide) {
      return Row(
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 16),
          Expanded(child: cards[1]),
          const SizedBox(width: 16),
          Expanded(child: cards[2]),
          const SizedBox(width: 16),
          Expanded(child: cards[3]),
        ],
      );
    }

    return Column(
      children: [
        cards[0],
        const SizedBox(height: 12),
        cards[1],
        const SizedBox(height: 12),
        cards[2],
        const SizedBox(height: 12),
        cards[3],
      ],
    );
  }
}
class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String delta;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.delta,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: _textMuted)),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _primaryDark,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              delta,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PosShowcase extends StatelessWidget {
  final bool isWide;

  const _PosShowcase({required this.isWide});

  @override
  Widget build(BuildContext context) {
    if (isWide) {
      return Row(
        children: const [
          Expanded(flex: 2, child: _PosFilterPanel()),
          SizedBox(width: 16),
          Expanded(flex: 4, child: _PosProductGrid()),
          SizedBox(width: 16),
          Expanded(flex: 3, child: _PosCartPanel()),
        ],
      );
    }

    return Column(
      children: const [
        _PosFilterPanel(),
        SizedBox(height: 16),
        _PosProductGrid(),
        SizedBox(height: 16),
        _PosCartPanel(),
      ],
    );
  }
}

class _PosFilterPanel extends StatelessWidget {
  const _PosFilterPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kategori', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: 'Cari produk',
              prefixIcon: const Icon(Icons.search, color: _primaryBlue),
              filled: true,
              fillColor: const Color(0xFFF3F8FF),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _panelBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _primaryBlue),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _ChipPill(label: 'Semua', active: true),
              _ChipPill(label: 'ATK'),
              _ChipPill(label: 'Minuman'),
              _ChipPill(label: 'Makanan'),
              _ChipPill(label: 'Aksesoris'),
            ],
          ),
          const SizedBox(height: 16),
          const _SwitchRow(label: 'Tampilkan stok tersedia'),
          const SizedBox(height: 16),
          _GhostButton(label: 'Filter lanjutan', icon: Icons.tune, onTap: null),
        ],
      ),
    );
  }
}

class _PosProductGrid extends StatelessWidget {
  const _PosProductGrid();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: GridView.builder(
        shrinkWrap: true,
        itemCount: _demoProducts.length,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.25,
        ),
        itemBuilder: (context, index) {
          final item = _demoProducts[index];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F8FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: item.inStock ? _primaryBlue : _panelBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _primaryDark,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  item.price,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _primaryDark,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _StockPill(inStock: item.inStock, stock: item.stock),
                    _GhostButton(label: 'Tambah', icon: Icons.add, onTap: null),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PosCartPanel extends StatelessWidget {
  const _PosCartPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Keranjang', style: TextStyle(fontWeight: FontWeight.w600)),
              _Badge(label: '3 item'),
            ],
          ),
          const SizedBox(height: 12),
          _InfoField(label: 'Pelanggan umum', trailing: Icons.expand_more),
          const SizedBox(height: 14),
          const _CartItem(
            name: 'Pulpen Gel Navy',
            qty: 2,
            price: 'Rp 22.000',
          ),
          const _CartItem(
            name: 'Notebook Premium',
            qty: 1,
            price: 'Rp 45.000',
          ),
          const _CartItem(
            name: 'Marker Artline',
            qty: 3,
            price: 'Rp 75.000',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F8FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _panelBorder),
            ),
            child: Column(
              children: const [
                _TotalRow(label: 'Subtotal', value: 'Rp 142.000'),
                SizedBox(height: 6),
                _TotalRow(label: 'Diskon', value: 'Rp 0'),
                SizedBox(height: 6),
                _TotalRow(label: 'Pajak', value: 'Rp 0'),
                Divider(height: 20),
                _TotalRow(label: 'Total', value: 'Rp 142.000', highlight: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.credit_card),
              label: const Text('Proses Pembayaran'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _InventoryTable extends StatelessWidget {
  final bool isWide;

  const _InventoryTable({required this.isWide});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: const MaterialStatePropertyAll(Color(0xFFDDEFFF)),
          dataRowMinHeight: 52,
          columns: const [
            DataColumn(label: Text('Produk')),
            DataColumn(label: Text('Kategori')),
            DataColumn(label: Text('Harga')),
            DataColumn(label: Text('Stok')),
            DataColumn(label: Text('Status')),
          ],
          rows: _demoInventory
              .map(
                (row) => DataRow(cells: [
                  DataCell(Text(row.name)),
                  DataCell(Text(row.category)),
                  DataCell(Text(row.price)),
                  DataCell(Text(row.stock.toString())),
                  DataCell(_StatusPill(label: row.status, color: row.statusColor)),
                ]),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  final bool isWide;

  const _ReportSection({required this.isWide});

  @override
  Widget build(BuildContext context) {
    return isWide
        ? Row(
            children: const [
              Expanded(flex: 3, child: _ReportChart()),
              SizedBox(width: 16),
              Expanded(flex: 2, child: _ReportTable()),
            ],
          )
        : Column(
            children: const [
              _ReportChart(),
              SizedBox(height: 16),
              _ReportTable(),
            ],
          );
  }
}

class _ReportChart extends StatelessWidget {
  const _ReportChart();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Performa Harian', style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 12),
          _ChartPlaceholder(),
        ],
      ),
    );
  }
}

class _ReportTable extends StatelessWidget {
  const _ReportTable();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kasir Terbaik', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ..._demoCashier.map(
            (c) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F8FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _panelBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _primaryBlue.withOpacity(0.15),
                    child: Text(
                      c.initials,
                      style: const TextStyle(color: _primaryBlue),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _primaryDark,
                          ),
                        ),
                        Text(c.shift, style: const TextStyle(color: _textMuted)),
                      ],
                    ),
                  ),
                  Text(
                    c.sales,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginShowcase extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Column(
        children: [
          const Text(
            'Masuk ke Kasir Premium',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Text(
            'Satu akun untuk semua outlet. Aman, cepat, dan elegan.',
            style: TextStyle(color: _textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              hintText: 'Email',
              prefixIcon: const Icon(Icons.email_outlined, color: _primaryBlue),
              filled: true,
              fillColor: const Color(0xFFF3F8FF),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _panelBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _primaryBlue),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline, color: _primaryBlue),
              filled: true,
              fillColor: const Color(0xFFF3F8FF),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _panelBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _primaryBlue),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Masuk'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SectionTitle({required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: _textMuted)),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _GhostButton({required this.label, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: _primaryBlue),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _primaryBlue,
        side: const BorderSide(color: _panelBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _ChipPill extends StatelessWidget {
  final String label;
  final bool active;

  const _ChipPill({required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    final bg = active ? const Color(0xFFD8EBFF) : const Color(0xFFEAF2FF);
    final color = active ? _primaryBlue : _textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _panelBorder),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;

  const _SwitchRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label)),
        Switch(
          value: true,
          onChanged: (_) {},
          activeColor: _primaryBlue,
        ),
      ],
    );
  }
}

class _PillInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PillInfo({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _panelBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: _primaryBlue, size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: _textMuted)),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;

  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _primaryBlue.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: _primaryDark, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _InfoField extends StatelessWidget {
  final String label;
  final IconData trailing;

  const _InfoField({required this.label, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _panelBorder),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Icon(trailing, color: _textMuted),
        ],
      ),
    );
  }
}

class _CartItem extends StatelessWidget {
  final String name;
  final int qty;
  final String price;

  const _CartItem({required this.name, required this.qty, required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _panelBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('$qty item', style: const TextStyle(color: _textMuted)),
              ],
            ),
          ),
          Text(price, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _TotalRow({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final style = highlight
        ? const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _primaryDark)
        : const TextStyle(color: _textMuted);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}
class _ChartPlaceholder extends StatelessWidget {
  const _ChartPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _panelBorder),
      ),
      child: CustomPaint(
        painter: _ChartPainter(),
        child: const Center(
          child: Text('Chart Preview', style: TextStyle(color: _textMuted)),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = _primaryBlue
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = const Color(0x332F80ED)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x332F80ED), Color(0x002F80ED)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final points = [
      Offset(0, size.height * 0.78),
      Offset(size.width * 0.18, size.height * 0.62),
      Offset(size.width * 0.35, size.height * 0.7),
      Offset(size.width * 0.55, size.height * 0.48),
      Offset(size.width * 0.75, size.height * 0.52),
      Offset(size.width * 0.92, size.height * 0.3),
    ];

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

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _StockPill extends StatelessWidget {
  final bool inStock;
  final int stock;

  const _StockPill({required this.inStock, required this.stock});

  @override
  Widget build(BuildContext context) {
    final color = inStock ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        inStock ? 'Stok $stock' : 'Habis',
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    gradient: _panelGradient,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: _panelBorder),
    boxShadow: const [
      BoxShadow(
        color: _panelShadow,
        blurRadius: 18,
        offset: Offset(0, 10),
      ),
    ],
  );
}

class _DemoProduct {
  final String name;
  final String price;
  final int stock;
  final bool inStock;

  const _DemoProduct({
    required this.name,
    required this.price,
    required this.stock,
    required this.inStock,
  });
}

class _DemoInventoryRow {
  final String name;
  final String category;
  final String price;
  final int stock;
  final String status;
  final Color statusColor;

  const _DemoInventoryRow({
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    required this.status,
    required this.statusColor,
  });
}

class _DemoCashierRow {
  final String initials;
  final String name;
  final String shift;
  final String sales;

  const _DemoCashierRow({
    required this.initials,
    required this.name,
    required this.shift,
    required this.sales,
  });
}

const _demoProducts = [
  _DemoProduct(name: 'Pulpen Navy', price: 'Rp 12.000', stock: 12, inStock: true),
  _DemoProduct(name: 'Notebook Linen', price: 'Rp 45.000', stock: 8, inStock: true),
  _DemoProduct(name: 'Spidol Color', price: 'Rp 18.000', stock: 0, inStock: false),
  _DemoProduct(name: 'Planner 2025', price: 'Rp 60.000', stock: 5, inStock: true),
];

const _demoInventory = [
  _DemoInventoryRow(
    name: 'Pulpen Gel Navy',
    category: 'ATK',
    price: 'Rp 12.000',
    stock: 12,
    status: 'Normal',
    statusColor: Color(0xFF22C55E),
  ),
  _DemoInventoryRow(
    name: 'Notebook Linen',
    category: 'ATK',
    price: 'Rp 45.000',
    stock: 4,
    status: 'Menipis',
    statusColor: Color(0xFFF59E0B),
  ),
  _DemoInventoryRow(
    name: 'Spidol Color',
    category: 'ATK',
    price: 'Rp 18.000',
    stock: 0,
    status: 'Habis',
    statusColor: Color(0xFFEF4444),
  ),
];

const _demoCashier = [
  _DemoCashierRow(initials: 'WA', name: 'Wahyu', shift: 'Shift Pagi', sales: 'Rp 4.8 jt'),
  _DemoCashierRow(initials: 'NI', name: 'Nina', shift: 'Shift Siang', sales: 'Rp 3.1 jt'),
  _DemoCashierRow(initials: 'AD', name: 'Adi', shift: 'Shift Malam', sales: 'Rp 2.9 jt'),
];
