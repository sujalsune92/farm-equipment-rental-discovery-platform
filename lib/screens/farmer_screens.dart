import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/app_theme.dart';
import '../widgets/widgets.dart';

// ──────────────────────────────────────────────────────────────────────────────
// FarmerHomeScreen
// ──────────────────────────────────────────────────────────────────────────────
class FarmerHomeScreen extends StatefulWidget {
  const FarmerHomeScreen({super.key});
  @override State<FarmerHomeScreen> createState() => _FarmerHomeScreenState();
}
class _FarmerHomeScreenState extends State<FarmerHomeScreen> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final tabs = [
      const FarmerDiscoveryTab(),
      const FarmerBookingsTab(),
      const NotificationsTab(),
      const ProfileTab(),
    ];
    return Scaffold(
      body: tabs[_tab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Discover'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark_outline), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// FarmerDiscoveryTab
// ──────────────────────────────────────────────────────────────────────────────
class FarmerDiscoveryTab extends StatefulWidget {
  const FarmerDiscoveryTab({super.key});
  @override State<FarmerDiscoveryTab> createState() => _FarmerDiscoveryTabState();
}
class _FarmerDiscoveryTabState extends State<FarmerDiscoveryTab> {
  final _listingService  = ListingService();
  final _locationService = LocationService();
  final MapController _mapController = MapController();

  List<EquipmentListing>? _listings;
  bool _loading = false;
  String? _error;

  // Filters — using plain doubles instead of GeoPoint
  double _radiusKm = 25;
  String _type = '';
  double? _maxPrice;
  double _userLat = 18.5204; // Pune fallback
  double _userLng = 73.8567;

  @override
  void initState() { super.initState(); _loadListings(); }

  Future<void> _loadListings() async {
    setState(() { _loading = true; _error = null; });
    try {
      final pos = await _locationService.getCurrentPosition();
      if (pos != null) {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
      }
      final results = await _listingService.searchListings(
        lat: _userLat, lng: _userLng,
        radiusKm: _radiusKm,
        type: _type.isEmpty ? null : _type,
        maxPrice: _maxPrice,
      );
      if (mounted) {
        setState(() { _listings = results; _loading = false; });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(LatLng(_userLat, _userLng), 12);
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discover Equipment'), actions: [
        IconButton(icon: const Icon(Icons.filter_list), onPressed: () => _showFilterSheet()),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(icon: Icons.error_outline, title: 'Error', subtitle: _error!)
              : RefreshIndicator(
                  onRefresh: _loadListings,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _mapSection(),
                      if (_listings != null && _listings!.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: EmptyState(
                            icon: Icons.agriculture,
                            title: 'No Equipment Nearby',
                            subtitle: 'Try widening your radius or adding the first listing.',
                          ),
                        ),
                      if (_listings != null && _listings!.isNotEmpty) const SizedBox(height: 16),
                      if (_listings != null)
                        ..._listings!.map((l) => EquipmentCard(
                              listing: l,
                              onTap: () => Navigator.pushNamed(context, '/equipment-detail', arguments: l),
                            )),
                    ],
                  ),
                ),
    );
  }

  Widget _mapSection() {
    if (_listings == null) return const SizedBox.shrink();

    final markers = <Marker>[
      Marker(
        point: LatLng(_userLat, _userLng),
        width: 36,
        height: 36,
        child: const Icon(Icons.my_location, color: AppColors.accent, size: 30),
      ),
      ..._listings!.map((l) => Marker(
            point: LatLng(l.latitude, l.longitude),
            width: 44,
            height: 44,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/equipment-detail', arguments: l),
              child: const Icon(Icons.location_on, color: AppColors.primary, size: 36),
            ),
          )),
    ];

    return SizedBox(
      height: 260,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: LatLng(_userLat, _userLng),
          initialZoom: 12,
          interactionOptions: const InteractionOptions(flags: ~InteractiveFlag.rotate),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'com.kisanyantra.app',
          ),
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FilterSheet(
        radius: _radiusKm,
        type: _type,
        maxPrice: _maxPrice,
        onApply: (r, t, p) {
          setState(() { _radiusKm = r; _type = t; _maxPrice = p; });
          _loadListings();
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Filter Sheet Widget
// ──────────────────────────────────────────────────────────────────────────────
class _FilterSheet extends StatefulWidget {
  final double radius;
  final String type;
  final double? maxPrice;
  final Function(double, String, double) onApply;
  const _FilterSheet({required this.radius, required this.type, this.maxPrice, required this.onApply});
  @override State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late double _radius; late String _type; late double _maxPrice;
  @override void initState() { super.initState(); _radius = widget.radius; _type = widget.type; _maxPrice = widget.maxPrice ?? 5000; }
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Filter Equipment', style: Theme.of(context).textTheme.headlineMedium),
          const Spacer(),
          TextButton(onPressed: () => setState(() { _radius = 25; _type = ''; _maxPrice = 5000; }), child: const Text('Reset')),
        ]),
        const SizedBox(height: 16),
        Text('Search Radius: ${_radius.toInt()} km', style: Theme.of(context).textTheme.titleMedium),
        Slider(value: _radius, min: 5, max: 100, divisions: 19, label: '${_radius.toInt()} km',
            activeColor: AppColors.primary, onChanged: (v) => setState(() => _radius = v)),
        const SizedBox(height: 12),
        Text('Equipment Type', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: [
          ChoiceChip(label: const Text('All'), selected: _type.isEmpty,
              onSelected: (_) => setState(() => _type = ''),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(color: _type.isEmpty ? Colors.white : null, fontWeight: FontWeight.w600)),
          ...AppConstants.equipmentTypes.map((t) => ChoiceChip(
            label: Text(t), selected: _type == t,
            onSelected: (_) => setState(() => _type = t),
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(color: _type == t ? Colors.white : null, fontWeight: FontWeight.w600),
          )),
        ]),
        const SizedBox(height: 16),
        Text('Max Price: ₹${_maxPrice.toInt()}/day', style: Theme.of(context).textTheme.titleMedium),
        Slider(value: _maxPrice, min: 100, max: 10000, divisions: 99, label: '₹${_maxPrice.toInt()}',
            activeColor: AppColors.primary, onChanged: (v) => setState(() => _maxPrice = v)),
        const SizedBox(height: 16),
        PrimaryButton(text: 'Apply Filters', onPressed: () { Navigator.pop(context); widget.onApply(_radius, _type, _maxPrice); }),
      ]),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// EquipmentDetailScreen
// ──────────────────────────────────────────────────────────────────────────────
class EquipmentDetailScreen extends StatelessWidget {
  final EquipmentListing listing;
  const EquipmentDetailScreen({super.key, required this.listing});

  @override
  Widget build(BuildContext context) {
    final reviewService = ReviewService();
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 280, pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: listing.imageUrls.isNotEmpty
                ? Image.network(listing.imageUrls.first, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: AppColors.background,
                        child: const Icon(Icons.agriculture, size: 80, color: AppColors.primary)))
                : Container(color: AppColors.background,
                    child: const Icon(Icons.agriculture, size: 80, color: AppColors.primary)),
          ),
        ),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(listing.name, style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 4),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(listing.type, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700))),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₹${listing.pricePerDay.toInt()}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary)),
                const Text('/day', style: TextStyle(color: AppColors.textSecondary)),
              ]),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              RatingBarIndicator(rating: listing.averageRating,
                  itemBuilder: (_, __) => const Icon(Icons.star, color: AppColors.accent),
                  itemCount: 5, itemSize: 18),
              const SizedBox(width: 6),
              Text('${listing.averageRating.toStringAsFixed(1)} · ${listing.totalBookings} rentals',
                  style: Theme.of(context).textTheme.bodyMedium),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.location_on, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(listing.address, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14))),
            ]),
            if (listing.distanceKm != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.directions, size: 16, color: AppColors.stone),
                const SizedBox(width: 8),
                Text('${listing.distanceKm!.toStringAsFixed(1)} km from your location',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ]),
            ],
            const SizedBox(height: 20), const Divider(), const SizedBox(height: 16),
            Text('About this Equipment', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(listing.description, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6)),
            const SizedBox(height: 20), const Divider(), const SizedBox(height: 16),
            Text('Owner', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Row(children: [
              CircleAvatar(backgroundColor: AppColors.primary,
                  child: Text(listing.ownerName.isNotEmpty ? listing.ownerName[0].toUpperCase() : 'O',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(listing.ownerName, style: Theme.of(context).textTheme.titleMedium),
                Row(children: [
                  const Icon(Icons.star, size: 14, color: AppColors.accent), const SizedBox(width: 4),
                  Text('${listing.ownerRating.toStringAsFixed(1)} rating', style: Theme.of(context).textTheme.bodyMedium),
                ]),
              ])),
            ]),
            const SizedBox(height: 20), const Divider(),
            SectionHeader(title: 'Reviews'),
            StreamBuilder<List<ReviewModel>>(
              stream: reviewService.getListingReviews(listing.id),
              builder: (_, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                if (snap.data!.isEmpty) return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No reviews yet.', style: TextStyle(color: AppColors.textSecondary)),
                );
                return Column(children: snap.data!.take(5).map((r) => _reviewTile(context, r)).toList());
              },
            ),
            const SizedBox(height: 80),
          ]),
        )),
      ]),
      bottomNavigationBar: SafeArea(child: Padding(
        padding: const EdgeInsets.all(16),
        child: PrimaryButton(
          text: 'Request Booking', icon: Icons.calendar_month,
          onPressed: () => Navigator.pushNamed(context, '/booking-request', arguments: listing),
        ),
      )),
    );
  }

  Widget _reviewTile(BuildContext context, ReviewModel r) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        CircleAvatar(radius: 14, backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(r.farmerName.isNotEmpty ? r.farmerName[0] : 'F',
                style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700))),
        const SizedBox(width: 8),
        Text(r.farmerName, style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        RatingBarIndicator(rating: r.rating,
            itemBuilder: (_, __) => const Icon(Icons.star, color: AppColors.accent),
            itemCount: 5, itemSize: 14),
      ]),
      const SizedBox(height: 6),
      Text(r.comment, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 8), const Divider(height: 1),
    ]));
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// BookingRequestScreen
// ──────────────────────────────────────────────────────────────────────────────
class BookingRequestScreen extends StatefulWidget {
  final EquipmentListing listing;
  const BookingRequestScreen({super.key, required this.listing});
  @override State<BookingRequestScreen> createState() => _BookingRequestScreenState();
}
class _BookingRequestScreenState extends State<BookingRequestScreen> {
  final _bookingService = BookingService();
  final _notifService   = NotificationService();
  final _usageCtrl      = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _loading = false;

  int get _days => _startDate != null && _endDate != null ? _endDate!.difference(_startDate!).inDays + 1 : 0;
  double get _total => _days * widget.listing.pricePerDay;

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context, initialDate: now, firstDate: now, lastDate: now.add(const Duration(days: 180)),
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary)), child: child!),
    );
    if (picked == null) return;
    setState(() { if (isStart) { _startDate = picked; if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null; } else { _endDate = picked; } });
  }

  Future<void> _submit() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select rental dates.')));
      return;
    }
    // Check conflict
    final conflict = await _bookingService.hasConflict(widget.listing.id, _startDate!, _endDate!);
    if (conflict) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Equipment is not available for these dates.')));
      return;
    }
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    try {
      final booking = BookingModel(
        id: '',
        listingId: widget.listing.id,
        listingName: widget.listing.name,
        listingType: widget.listing.type,
        listingImageUrl: widget.listing.imageUrls.isNotEmpty ? widget.listing.imageUrls.first : '',
        farmerId: auth.currentUser!.id,   // ← .id not .uid
        farmerName: auth.currentUser!.name,
        farmerPhone: auth.currentUser!.phone,
        ownerId: widget.listing.ownerId,
        ownerName: widget.listing.ownerName,
        startDate: _startDate!,
        endDate: _endDate!,
        pricePerDay: widget.listing.pricePerDay,
        totalPrice: _total,
        status: AppConstants.statusPending,
        usageDetails: _usageCtrl.text.isNotEmpty ? _usageCtrl.text : null,
        createdAt: DateTime.now(),
      );
      await _bookingService.createBooking(booking);
      await _notifService.send(
        userId: widget.listing.ownerId,
        title: 'New Booking Request',
        body: '${auth.currentUser!.name} wants to rent "${widget.listing.name}".',
        type: 'booking_request',
        referenceId: widget.listing.id,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Booking request sent!'), backgroundColor: AppColors.success));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Booking')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
          Container(width: 56, height: 56,
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.agriculture, color: AppColors.primary, size: 30)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.listing.name, style: Theme.of(context).textTheme.titleLarge),
            Text('₹${widget.listing.pricePerDay.toInt()}/day · ${widget.listing.ownerName}', style: Theme.of(context).textTheme.bodyMedium),
          ])),
        ]))),
        const SizedBox(height: 24),
        Text('Select Dates', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _datePicker(label: 'Start Date', date: _startDate, onTap: () => _pickDate(true))),
          const SizedBox(width: 12),
          Expanded(child: _datePicker(label: 'End Date', date: _endDate, onTap: () => _pickDate(false))),
        ]),
        if (_days > 0) ...[
          const SizedBox(height: 16),
          Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2))),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('$_days days × ₹${widget.listing.pricePerDay.toInt()}', style: Theme.of(context).textTheme.titleMedium),
                Text('₹${_total.toInt()}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ])),
        ],
        const SizedBox(height: 20),
        Text('Usage Details (Optional)', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        TextFormField(controller: _usageCtrl, maxLines: 3,
            decoration: const InputDecoration(hintText: 'Describe intended use...')),
        const SizedBox(height: 32),
        PrimaryButton(text: 'Send Booking Request', icon: Icons.send, isLoading: _loading, onPressed: _submit),
      ])),
    );
  }

  Widget _datePicker({required String label, required DateTime? date, required VoidCallback onTap}) {
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: date != null ? AppColors.primary : AppColors.divider)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(date != null ? DateFormat('dd MMM yy').format(date) : 'Select',
            style: TextStyle(fontWeight: FontWeight.w700, color: date != null ? AppColors.textPrimary : AppColors.textHint)),
      ]),
    ));
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// FarmerBookingsTab
// ──────────────────────────────────────────────────────────────────────────────
class FarmerBookingsTab extends StatelessWidget {
  const FarmerBookingsTab({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final bookingService = BookingService();
    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      body: StreamBuilder<List<BookingModel>>(
        stream: bookingService.getFarmerBookings(auth.currentUser!.id), // ← .id not .uid
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snap.hasData || snap.data!.isEmpty) return const EmptyState(icon: Icons.bookmark_border, title: 'No Bookings Yet', subtitle: 'Your rental requests will appear here.');
          return ListView.builder(padding: const EdgeInsets.all(16), itemCount: snap.data!.length,
              itemBuilder: (_, i) => BookingCard(booking: snap.data![i],
                  onTap: () => Navigator.pushNamed(context, '/booking-detail', arguments: {'booking': snap.data![i], 'isOwner': false})));
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// BookingDetailScreen
// ──────────────────────────────────────────────────────────────────────────────
class BookingDetailScreen extends StatefulWidget {
  final BookingModel booking;
  final bool isOwner;
  const BookingDetailScreen({super.key, required this.booking, this.isOwner = false});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  final _bs   = BookingService();
  final _ns   = NotificationService();
  final _rs   = ReviewService();
  final _ls   = ListingService();
  final _loc  = LocationService();
  final MapController _mapController = MapController();
  late final Future<EquipmentListing?> _listingFuture;
  LatLng? _userLatLng;
  List<LatLng> _routePoints = [];
  bool _routeLoading = false;

  @override
  void initState() {
    super.initState();
    _listingFuture = _ls.getListing(widget.booking.listingId);
    _loadUserLocation();
  }

  Future<void> _loadUserLocation() async {
    final pos = await _loc.getCurrentPosition();
    if (!mounted || pos == null) return;
    setState(() => _userLatLng = LatLng(pos.latitude, pos.longitude));
  }

  Future<void> _openDirections(EquipmentListing listing) async {
    final to = '${listing.latitude},${listing.longitude}';
    final from = _userLatLng != null ? '${_userLatLng!.latitude},${_userLatLng!.longitude}' : null;
    final url = from != null
        ? 'https://www.openstreetmap.org/directions?from=$from&to=$to'
        : 'https://www.openstreetmap.org/?mlat=${listing.latitude}&mlon=${listing.longitude}#map=16/${listing.latitude}/${listing.longitude}';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _maybeLoadRoute(EquipmentListing listing) async {
    if (_userLatLng == null || _routeLoading || _routePoints.isNotEmpty) return;
    setState(() => _routeLoading = true);
    try {
      final points = await _fetchRoute(
        _userLatLng!,
        LatLng(listing.latitude, listing.longitude),
      );
      if (!mounted) return;
      setState(() {
        _routePoints = points;
        _routeLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _routeLoading = false);
    }
  }

  Future<List<LatLng>> _fetchRoute(LatLng from, LatLng to) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${from.longitude},${from.latitude};${to.longitude},${to.latitude}?overview=full&geometries=geojson',
    );
    final res = await http.get(url);
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final routes = data['routes'] as List?;
    if (routes == null || routes.isEmpty) return [];
    final coords = routes.first['geometry']['coordinates'] as List<dynamic>;
    return coords
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
  }

  void _kickoffRoute(EquipmentListing listing) {
    if (_userLatLng == null || _routeLoading || _routePoints.isNotEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadRoute(listing));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final fmt  = DateFormat('EEEE, dd MMM yyyy');
    final booking = widget.booking;

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Details')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.agriculture, color: AppColors.primary)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(booking.listingName, style: Theme.of(context).textTheme.titleLarge),
            Text(booking.listingType, style: Theme.of(context).textTheme.bodyMedium),
          ])),
          StatusBadge(booking.status),
        ]))),
        const SizedBox(height: 16),
        _section(context, 'Rental Period', [
          _row('From', fmt.format(booking.startDate)),
          _row('To',   fmt.format(booking.endDate)),
          _row('Duration', '${booking.durationDays} days'),
        ]),
        const SizedBox(height: 12),
        _section(context, 'Payment Summary', [
          _row('Price/day', '₹${booking.pricePerDay.toInt()}'),
          _row('Total',     '₹${booking.totalPrice.toInt()}', highlight: true),
        ]),
        FutureBuilder<EquipmentListing?>(
          future: _listingFuture,
          builder: (ctx, snap) {
            final listing = snap.data;
            if (snap.connectionState == ConnectionState.waiting) {
              return Column(children: [
                const SizedBox(height: 12),
                _personSection(context, listing),
                const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Center(child: CircularProgressIndicator())),
              ]);
            }

            if (listing != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _kickoffRoute(listing));
            }

            return Column(children: [
              const SizedBox(height: 12),
              _personSection(context, listing),
              if (listing != null) ...[
                const SizedBox(height: 12),
                _section(context, 'Location', [
                  _row('Address', listing.address),
                  _row('Coordinates', '${listing.latitude.toStringAsFixed(4)}, ${listing.longitude.toStringAsFixed(4)}'),
                ]),
                const SizedBox(height: 10),
                _mapCard(listing),
              ],
            ]);
          },
        ),
        if (booking.usageDetails != null) ...[
          const SizedBox(height: 12),
          _section(context, 'Usage Details', [Text(booking.usageDetails!)]),
        ],
        if (booking.declineReason != null) ...[
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.error.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.info_outline, color: AppColors.error, size: 18), const SizedBox(width: 8),
                Expanded(child: Text('Reason: ${booking.declineReason}', style: const TextStyle(color: AppColors.error))),
              ])),
        ],
        const SizedBox(height: 24),

        if (widget.isOwner && booking.status == AppConstants.statusPending)
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(Icons.close, color: AppColors.error),
              label: const Text('Decline', style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
              onPressed: () => _showDeclineDialog(context, auth),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton.icon(
              icon: const Icon(Icons.check), label: const Text('Approve'),
              onPressed: () async {
                await _bs.updateStatus(booking.id, status: AppConstants.statusApproved);
                await _ns.send(userId: booking.farmerId, title: 'Booking Approved!',
                    body: 'Your request for "${booking.listingName}" was approved.', type: 'booking_update');
                if (context.mounted) Navigator.pop(context);
              },
            )),
          ]),

        if (widget.isOwner && booking.status == AppConstants.statusApproved)
          PrimaryButton(text: 'Mark as Completed', icon: Icons.done_all, onPressed: () async {
            await _bs.markCompleted(booking.id);
            await _ns.send(userId: booking.farmerId, title: 'Booking Completed',
                body: 'Your rental of "${booking.listingName}" is marked complete.', type: 'booking_update');
            if (context.mounted) Navigator.pop(context);
          }),

        if (!widget.isOwner && booking.status == AppConstants.statusCompleted)
          PrimaryButton(text: 'Leave a Review', icon: Icons.rate_review,
              onPressed: () => _showReviewDialog(context, auth)),
      ])),
    );
  }

  Widget _personSection(BuildContext context, EquipmentListing? listing) {
    final booking = widget.booking;
    final heading = widget.isOwner ? 'Farmer' : 'Owner';
    final name    = widget.isOwner ? booking.farmerName : (listing?.ownerName ?? booking.ownerName);
    final phone   = widget.isOwner
        ? booking.farmerPhone
        : (listing?.ownerPhone ?? 'Not provided');
    return Column(children: [
      _section(context, heading, [
        _row('Name', name),
        _row('Phone', phone),
      ]),
    ]);
  }

  Widget _mapCard(EquipmentListing listing) {
    final dest = LatLng(listing.latitude, listing.longitude);
    final markers = <Marker>[
      Marker(
        point: dest,
        width: 40,
        height: 40,
        child: const Icon(Icons.place, color: AppColors.primary, size: 34),
      ),
      if (_userLatLng != null)
        Marker(
          point: _userLatLng!,
          width: 36,
          height: 36,
          child: const Icon(Icons.my_location, color: AppColors.accent, size: 30),
        ),
    ];

    final polyPoints = _routePoints.isNotEmpty
        ? _routePoints
        : (_userLatLng != null ? [_userLatLng!, dest] : <LatLng>[]);
    final polylines = polyPoints.length >= 2
        ? [
            Polyline(
              points: polyPoints,
              color: AppColors.primary.withOpacity(0.6),
              strokeWidth: 4,
            ),
          ]
        : <Polyline>[];

    return Card(child: Column(children: [
      SizedBox(
        height: 240,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: dest,
            initialZoom: 14,
          ),
          children: [
            TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: const ['a', 'b', 'c']),
            PolylineLayer(polylines: polylines),
            MarkerLayer(markers: markers),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Row(children: [
          Expanded(child: Text('OpenStreetMap preview. Tap for turn-by-turn in browser.', style: Theme.of(context).textTheme.bodySmall)),
          TextButton.icon(onPressed: () => _openDirections(listing), icon: const Icon(Icons.directions), label: const Text('Directions')),
        ]),
      ),
    ]));
  }

  void _showDeclineDialog(BuildContext context, AuthProvider auth) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Decline Booking'),
      content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Reason for declining...'), maxLines: 2),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          await _bs.updateStatus(widget.booking.id, status: AppConstants.statusDeclined, declineReason: ctrl.text);
          await _ns.send(userId: widget.booking.farmerId, title: 'Booking Declined',
              body: 'Your request for "${widget.booking.listingName}" was declined.', type: 'booking_update');
          if (context.mounted) { Navigator.pop(context); Navigator.pop(context); }
        }, child: const Text('Decline')),
      ],
    ));
  }

  void _showReviewDialog(BuildContext context, AuthProvider auth) {
    double rating = 4;
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
      title: const Text('Leave a Review'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        RatingBar.builder(initialRating: rating,
            itemBuilder: (_, __) => const Icon(Icons.star, color: AppColors.accent),
            onRatingUpdate: (r) => setSt(() => rating = r)),
        const SizedBox(height: 12),
        TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Write your review...'), maxLines: 3),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          await _rs.submitReview(ReviewModel(
            id: '', bookingId: widget.booking.id, listingId: widget.booking.listingId,
            farmerId: auth.currentUser!.id,
            farmerName: auth.currentUser!.name,
            ownerId: widget.booking.ownerId, rating: rating, comment: ctrl.text, createdAt: DateTime.now(),
          ));
          if (ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('Submit')),
      ],
    )));
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
      const SizedBox(height: 10),
      ...children,
    ])));
  }

  Widget _row(String label, String value, {bool highlight = false}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        Text(value, style: TextStyle(
            fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
            color: highlight ? AppColors.primary : AppColors.textPrimary,
            fontSize: highlight ? 16 : 14)),
      ],
    ));
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// NotificationsTab
// ──────────────────────────────────────────────────────────────────────────────
class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final ns = NotificationService();
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<List<AppNotification>>(
        stream: ns.getNotifications(auth.currentUser!.id), // ← .id
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.data!.isEmpty) return const EmptyState(icon: Icons.notifications_none, title: 'No Notifications', subtitle: 'You\'re all caught up!');
          return ListView.separated(
            padding: const EdgeInsets.all(16), itemCount: snap.data!.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final n = snap.data![i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: n.isRead ? AppColors.background : AppColors.primary.withOpacity(0.12),
                  child: Icon(_iconFor(n.type), color: n.isRead ? AppColors.textHint : AppColors.primary, size: 20)),
                title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700)),
                subtitle: Text(n.body),
                trailing: n.isRead ? null : Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                onTap: () => ns.markRead(n.id),
                contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              );
            },
          );
        },
      ),
    );
  }
  IconData _iconFor(String type) {
    switch (type) { case 'booking_request': return Icons.add_task; case 'review': return Icons.star_outline; default: return Icons.notifications_outlined; }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// ProfileTab
// ──────────────────────────────────────────────────────────────────────────────
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser!;
    final isAdmin = user.role == AppConstants.roleAdmin;
    final roleLabel = isAdmin ? 'Admin' : 'Member';
    final roleEmoji = isAdmin ? '🛡' : '🤝';
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Center(child: Column(children: [
          CircleAvatar(radius: 44, backgroundColor: AppColors.primary,
              child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800))),
          const SizedBox(height: 12),
          Text(user.name, style: Theme.of(context).textTheme.headlineMedium),
          Container(margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text('$roleEmoji $roleLabel',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))),
        ])),
        const SizedBox(height: 28),
        Card(child: Column(children: [
          _pRow(Icons.email_outlined, 'Email', user.email),
          const Divider(height: 1),
          _pRow(Icons.phone_outlined, 'Phone', user.phone),
        ])),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.logout, color: AppColors.error),
          label: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
          onPressed: () async {
            await auth.signOut();
            if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
          },
        ),
      ]),
    );
  }
  Widget _pRow(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14)),
    );
  }
}
