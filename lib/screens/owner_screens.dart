import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/auth_provider.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/app_theme.dart';
import '../widgets/widgets.dart';
import 'farmer_screens.dart'; // NotificationsTab, ProfileTab, BookingCard, BookingDetailScreen

// ──────────────────────────────────────────────────────────────────────────────
// OwnerHomeScreen
// ──────────────────────────────────────────────────────────────────────────────
class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});
  @override State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}
class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final tabs = [
      const OwnerDashboardTab(),
      const OwnerListingsTab(),
      const OwnerBookingsTab(),
      const NotificationsTab(),
      const ProfileTab(),
    ];
    return Scaffold(
      body: tabs[_tab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt),           label: 'Listings'),
          BottomNavigationBarItem(icon: Icon(Icons.book_online),        label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline),     label: 'Profile'),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// OwnerDashboardTab
// ──────────────────────────────────────────────────────────────────────────────
class OwnerDashboardTab extends StatelessWidget {
  const OwnerDashboardTab({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final bs   = BookingService();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 120, pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(gradient: LinearGradient(
                  colors: [AppColors.soil, Color(0xFF3E2723)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Welcome, ${auth.currentUser?.name.split(' ').first ?? 'Owner'} 👋',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                const Text('Manage your equipment listings', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ]),
            ),
          ),
        ),
        SliverPadding(padding: const EdgeInsets.all(16), sliver: SliverList(delegate: SliverChildListDelegate([
          StreamBuilder<List<BookingModel>>(
            stream: bs.getOwnerBookings(auth.currentUser!.id), // ← .id
            builder: (_, snap) {
              final all      = snap.data ?? [];
              final pending  = all.where((b) => b.status == AppConstants.statusPending).length;
              final approved = all.where((b) => b.status == AppConstants.statusApproved || b.status == AppConstants.statusInUse).length;
              final done     = all.where((b) => b.status == AppConstants.statusCompleted).length;
              return Row(children: [
                _stat(context, '$pending',  'Pending',  Icons.hourglass_empty,    AppColors.warning),
                const SizedBox(width: 12),
                _stat(context, '$approved', 'Active',   Icons.check_circle_outline, AppColors.success),
                const SizedBox(width: 12),
                _stat(context, '$done',     'Done',     Icons.done_all,            AppColors.stone),
              ]);
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<BookingModel>>(
            stream: bs.getOwnerBookings(auth.currentUser!.id),
            builder: (_, snap) {
              final all = snap.data ?? [];
              final revenue = all.where((b) => b.paymentStatus == 'paid').fold<double>(0, (sum, b) => sum + b.totalPrice);
              final daysHorizon = 30;
              final periodStart = DateTime.now().subtract(const Duration(days: 30));
              final periodBookings = all.where((b) => b.startDate.isAfter(periodStart)).toList();
              final utilization = _computeUtilization(periodBookings, daysHorizon);
              final repeatFarmers = all.map((b) => b.farmerId).fold<Map<String,int>>({}, (map, id) { map[id] = (map[id] ?? 0) + 1; return map; });
              final repeatPct = repeatFarmers.isEmpty ? 0 : (repeatFarmers.values.where((c) => c > 1).length / repeatFarmers.length * 100);
              return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('30-day Insights', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _insightRow('Revenue (paid)', '₹${revenue.toStringAsFixed(0)}'),
                  _insightRow('Utilization', '${utilization.toStringAsFixed(1)}%'),
                  _insightRow('Repeat renters', '${repeatPct.toStringAsFixed(0)}%'),
                ],
              )));
            },
          ),
          const SizedBox(height: 20),
          SectionHeader(title: 'Pending Requests'),
          StreamBuilder<List<BookingModel>>(
            stream: bs.getOwnerBookings(auth.currentUser!.id),
            builder: (_, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final pending = snap.data!.where((b) => b.status == AppConstants.statusPending).take(3).toList();
              if (pending.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('No pending requests.', style: TextStyle(color: AppColors.textSecondary))));
              return Column(children: pending.map((b) => BookingCard(booking: b,
                  onTap: () => Navigator.pushNamed(context, '/booking-detail', arguments: {'booking': b, 'isOwner': true}))).toList());
            },
          ),
        ]))),
      ]),
    );
  }

  Widget _stat(BuildContext context, String value, String label, IconData icon, Color color) {
    return Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
      Icon(icon, color: color, size: 26),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
    ]))));
  }

  double _computeUtilization(List<BookingModel> bookings, int daysHorizon) {
    final horizonHours = daysHorizon * 24.0;
    double bookedHours = 0;
    for (final b in bookings) {
      if (b.durationType == 'hourly' && b.startTime != null && b.endTime != null) {
        bookedHours += b.endTime!.difference(b.startTime!).inMinutes / 60.0;
      } else if (b.durationType == 'half_day') {
        bookedHours += 12;
      } else {
        bookedHours += (b.durationDays * 24);
      }
    }
    if (horizonHours == 0) return 0;
    final pct = (bookedHours / horizonHours) * 100;
    return pct.clamp(0, 100);
  }

  Widget _insightRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// OwnerListingsTab
// ──────────────────────────────────────────────────────────────────────────────
class OwnerListingsTab extends StatelessWidget {
  const OwnerListingsTab({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final ls   = ListingService();
    return Scaffold(
      appBar: AppBar(title: const Text('My Listings')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'ownerListingsAddFab',
        icon: const Icon(Icons.add), label: const Text('Add Equipment'),
        backgroundColor: AppColors.primary,
        onPressed: () => Navigator.pushNamed(context, '/add-listing'),
      ),
      body: StreamBuilder<List<EquipmentListing>>(
        stream: ls.getOwnerListings(auth.currentUser!.id), // ← .id
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snap.hasData || snap.data!.isEmpty) return EmptyState(
            icon: Icons.add_box_outlined, title: 'No Listings Yet',
            subtitle: 'Add your first equipment to start getting bookings.',
            actionLabel: 'Add Equipment', onAction: () => Navigator.pushNamed(context, '/add-listing'),
          );
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: snap.data!.length,
            itemBuilder: (_, i) {
              final listing = snap.data![i];
              return Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: Container(width: 56, height: 56,
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: listing.imageUrls.isNotEmpty
                        ? ClipRRect(borderRadius: BorderRadius.circular(10),
                            child: Image.network(listing.imageUrls.first, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.agriculture, color: AppColors.primary)))
                        : const Icon(Icons.agriculture, color: AppColors.primary)),
                title: Text(listing.name, style: Theme.of(context).textTheme.titleMedium),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('₹${listing.pricePerDay.toInt()}/day · ${listing.type}', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: listing.isActive ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(listing.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(color: listing.isActive ? AppColors.success : AppColors.error, fontSize: 11, fontWeight: FontWeight.w700))),
                ]),
                trailing: PopupMenuButton(
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit')])),
                    PopupMenuItem(value: 'toggle', child: Row(children: [
                      Icon(listing.isActive ? Icons.visibility_off : Icons.visibility, size: 18),
                      const SizedBox(width: 8),
                      Text(listing.isActive ? 'Deactivate' : 'Activate'),
                    ])),
                  ],
                  onSelected: (v) async {
                    if (v == 'edit') Navigator.pushNamed(context, '/add-listing', arguments: listing);
                    else if (v == 'toggle') await ls.updateListing(listing.id, {'is_active': !listing.isActive});
                  },
                ),
              ));
            },
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// AddEditListingScreen — uses lat/lng doubles, NOT GeoPoint
// ──────────────────────────────────────────────────────────────────────────────
class AddEditListingScreen extends StatefulWidget {
  final EquipmentListing? existing;
  const AddEditListingScreen({super.key, this.existing});
  @override State<AddEditListingScreen> createState() => _AddEditListingScreenState();
}
class _AddEditListingScreenState extends State<AddEditListingScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _priceCtrl  = TextEditingController();
  final _addrCtrl   = TextEditingController();

  String _type = AppConstants.equipmentTypes.first;
  List<Uint8List> _newImageBytes = [];
  List<String> _existingImageUrls = [];
  bool _loading = false;
  bool _locating = false;

  // Plain doubles — no GeoPoint
  double? _lat;
  double? _lng;

  final _listingService  = ListingService();
  final _locationService = LocationService();

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final e = widget.existing!;
      _nameCtrl.text = e.name;
      _descCtrl.text = e.description;
      _priceCtrl.text = e.pricePerDay.toString();
      _addrCtrl.text  = e.address;
      _type = e.type;
      _existingImageUrls = List.from(e.imageUrls);
      _lat = e.latitude;   // ← latitude double
      _lng = e.longitude;  // ← longitude double
    } else {
      _detectLocation();
    }
  }

  Future<void> _detectLocation() async {
    setState(() => _locating = true);
    final pos = await _locationService.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() { _lat = pos.latitude; _lng = pos.longitude; });
      final addr = await _locationService.getAddressFromCoords(pos.latitude, pos.longitude);
      if (addr != null && mounted) setState(() => _addrCtrl.text = addr);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not detect location. Please enable location services and try again.')),
        );
      }
    }
    if (mounted) setState(() => _locating = false);
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 70);
    final remaining = AppConstants.maxImages - _existingImageUrls.length - _newImageBytes.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 5 images allowed.')));
      return;
    }
    final selected = picked.take(remaining).toList();
    final bytes = <Uint8List>[];
    for (final image in selected) {
      bytes.add(await image.readAsBytes());
    }
    if (!mounted) return;
    setState(() => _newImageBytes.addAll(bytes));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not detect location. Please tap the location button to set it.')));
      return;
    }
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    try {
      List<String> imageUrls = List.from(_existingImageUrls);
      if (_newImageBytes.isNotEmpty) {
        final id = _isEdit ? widget.existing!.id : DateTime.now().millisecondsSinceEpoch.toString();
        imageUrls.addAll(await _listingService.uploadImagesBytes(_newImageBytes, id));
      }

      final listing = EquipmentListing(
        id: _isEdit ? widget.existing!.id : '',
        ownerId:   auth.currentUser!.id,     // ← .id
        ownerName:  auth.currentUser!.name,
        ownerPhone: auth.currentUser!.phone,
        ownerRating: auth.currentUser!.averageRating,
        name:        _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        type:        _type,
        pricePerDay: double.parse(_priceCtrl.text),
        imageUrls:   imageUrls,
        latitude:    _lat!,    // ← plain double
        longitude:   _lng!,    // ← plain double
        address:     _addrCtrl.text.trim(),
        createdAt:   _isEdit ? widget.existing!.createdAt : DateTime.now(),
      );

      if (_isEdit) {
        await _listingService.updateListing(listing.id, listing.toMap());
      } else {
        await _listingService.createListing(listing);
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEdit ? 'Listing updated!' : 'Listing published!'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Listing' : 'Add Equipment')),
      body: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Equipment Photos', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        SizedBox(height: 110, child: ListView(scrollDirection: Axis.horizontal, children: [
          ..._existingImageUrls.map((url) => _thumb(
              child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported)),
              onRemove: () => setState(() => _existingImageUrls.remove(url)))),
          ..._newImageBytes.asMap().entries.map((entry) => _thumb(
                child: Image.memory(entry.value, fit: BoxFit.cover),
                onRemove: () => setState(() => _newImageBytes.removeAt(entry.key)),
              )),
          if (_existingImageUrls.length + _newImageBytes.length < AppConstants.maxImages)
            GestureDetector(onTap: _pickImages, child: Container(
              width: 100, margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(border: Border.all(color: AppColors.divider), borderRadius: BorderRadius.circular(10), color: AppColors.background),
              child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_photo_alternate, color: AppColors.primary, size: 28),
                SizedBox(height: 4),
                Text('Add Photo', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
              ]),
            )),
        ])),
        const SizedBox(height: 20),
        TextFormField(controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Equipment Name *', hintText: 'e.g., John Deere Tractor 5E'),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Equipment Type *'),
            items: AppConstants.equipmentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => _type = v!)),
        const SizedBox(height: 14),
        TextFormField(controller: _descCtrl, maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description *', hintText: 'Describe capacity, power, ideal use cases...'),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null),
        const SizedBox(height: 14),
        TextFormField(controller: _priceCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Price Per Day (₹) *', prefixIcon: Icon(Icons.currency_rupee)),
            validator: (v) { if (v == null || v.isEmpty) return 'Required'; if (double.tryParse(v) == null) return 'Invalid amount'; return null; }),
        const SizedBox(height: 14),
        TextFormField(controller: _addrCtrl,
            decoration: InputDecoration(
              labelText: 'Location / Address *', prefixIcon: const Icon(Icons.location_on_outlined),
        suffixIcon: IconButton(
          icon: _locating
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.my_location),
          onPressed: _locating ? null : _detectLocation,
          tooltip: 'Use current location',
        ),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null),
        if (_lat != null) Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('📍 ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 11, color: AppColors.success)),
        ),
        if (_lat != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(_lat!, _lng!),
                initialZoom: 15,
                interactionOptions: const InteractionOptions(flags: ~InteractiveFlag.rotate),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.kisanyantra.app',
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: LatLng(_lat!, _lng!),
                    width: 36,
                    height: 36,
                    child: const Icon(Icons.location_on, color: AppColors.primary, size: 34),
                  ),
                ]),
              ],
            ),
          ),
        ],
        const SizedBox(height: 28),
        PrimaryButton(
          text: _isEdit ? 'Update Listing' : 'Publish Listing',
          icon: _isEdit ? Icons.save : Icons.publish,
          isLoading: _loading, onPressed: _submit,
        ),
      ])),
    );
  }

  Widget _thumb({required Widget child, required VoidCallback onRemove}) {
    return Stack(children: [
      Container(width: 100, height: 100, margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: AppColors.background),
          clipBehavior: Clip.antiAlias, child: child),
      Positioned(top: 4, right: 12, child: GestureDetector(onTap: onRemove,
          child: Container(padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 14)))),
    ]);
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// OwnerBookingsTab
// ──────────────────────────────────────────────────────────────────────────────
class OwnerBookingsTab extends StatefulWidget {
  const OwnerBookingsTab({super.key});
  @override State<OwnerBookingsTab> createState() => _OwnerBookingsTabState();
}
class _OwnerBookingsTabState extends State<OwnerBookingsTab> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  @override void initState() { super.initState(); _tabCtrl = TabController(length: 4, vsync: this); }
  @override void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final bs   = BookingService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Requests'),
        bottom: TabBar(controller: _tabCtrl,
            tabs: const [Tab(text: 'Pending'), Tab(text: 'Approved'), Tab(text: 'Completed'), Tab(text: 'Declined')],
            labelColor: Colors.white, unselectedLabelColor: Colors.white60, indicatorColor: AppColors.accent),
      ),
      body: StreamBuilder<List<BookingModel>>(
        stream: bs.getOwnerBookings(auth.currentUser!.id),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final all = snap.data!;
          return TabBarView(controller: _tabCtrl, children: [
            AppConstants.statusPending, AppConstants.statusApproved,
            AppConstants.statusCompleted, AppConstants.statusDeclined,
          ].map((status) {
            final filtered = all.where((b) => b.status == status).toList();
            if (filtered.isEmpty) return EmptyState(icon: Icons.inbox_outlined, title: 'No $status Bookings', subtitle: '');
            return ListView.builder(padding: const EdgeInsets.all(16), itemCount: filtered.length,
                itemBuilder: (_, i) => BookingCard(booking: filtered[i],
                    onTap: () => Navigator.pushNamed(context, '/booking-detail', arguments: {'booking': filtered[i], 'isOwner': true})));
          }).toList());
        },
      ),
    );
  }
}
