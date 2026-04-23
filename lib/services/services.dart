import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';

final _sb = Supabase.instance.client;

// ─────────────────────────────────────────────────────────────────────────────
// AuthService
// ─────────────────────────────────────────────────────────────────────────────
class AuthService {
  Future<UserModel> _upsertUserProfile({
    required String uid,
    required String email,
    required String name,
    required String phone,
    String role = AppConstants.roleUser,
  }) async {
    final profile = {
      'id': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
    };
    final row = await _sb.from('users').upsert(profile).select().single();
    return UserModel.fromMap(row);
  }

  Future<UserModel> resolveUserProfile(
    User authUser, {
    required String fallbackEmail,
  }) async {
    final existing = await getUser(authUser.id);
    if (existing != null) return existing;

    final meta = authUser.userMetadata ?? {};
    final rawName = meta['name'] as String?;
    final name = rawName != null && rawName.trim().isNotEmpty
        ? rawName.trim()
        : (authUser.email ?? fallbackEmail).split('@').first;
    final phone = (meta['phone'] as String?) ?? '';
    final role = (meta['role'] as String?) ?? AppConstants.roleUser;
    return _upsertUserProfile(
      uid: authUser.id,
      email: authUser.email ?? fallbackEmail,
      name: name,
      phone: phone,
      role: role,
    );
  }

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    String role = AppConstants.roleUser,
  }) async {
    final res = await _sb.auth.signUp(email: email, password: password);
    final user = res.user;
    if (user == null) {
      throw const AuthException(
        'Please check your email to confirm signup.',
        code: 'email_confirmation_required',
      );
    }
    final uid = user.id;
    final profile = {
      'id': uid, 'name': name, 'email': email, 'phone': phone, 'role': role,
    };
    // Upsert in case the trigger already created a row.
    // If email confirmation is enabled, signup may not have an authenticated
    // session yet and RLS can reject this write (42501). In that case, rely on
    // the auth.users trigger to create the public.users row.
    try {
      await _sb.from('users').upsert(profile);
    } on PostgrestException catch (e) {
      if (e.code != '42501') rethrow;
    }
    return UserModel.fromMap({...profile, 'created_at': DateTime.now().toIso8601String()});
  }

  Future<UserModel?> login({required String email, required String password}) async {
    final res = await _sb.auth.signInWithPassword(email: email, password: password);
    final authUser = res.user ?? _sb.auth.currentUser;
    if (authUser == null) return null;

    return resolveUserProfile(authUser, fallbackEmail: email);
  }

  Future<UserModel?> getUser(String uid) async {
    final row = await _sb.from('users').select().eq('id', uid).maybeSingle();
    return row != null ? UserModel.fromMap(row) : null;
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    await _sb.from('users').update(data).eq('id', uid);
  }

  Future<void> resetPassword(String email) async {
    await _sb.auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() async => _sb.auth.signOut();

  User? get currentUser => _sb.auth.currentUser;
  Stream<AuthState> get authStateChanges => _sb.auth.onAuthStateChange;
}

// ─────────────────────────────────────────────────────────────────────────────
// StorageService
// ─────────────────────────────────────────────────────────────────────────────
class StorageService {
  Future<List<String>> uploadEquipmentImages(List<File> images, String listingId) async {
    final List<String> urls = [];
    for (int i = 0; i < images.length; i++) {
      final path = 'listings/$listingId/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final bytes = await images[i].readAsBytes();
      await _sb.storage
          .from(AppConstants.equipmentBucket)
          .uploadBinary(path, bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));
      urls.add(_sb.storage.from(AppConstants.equipmentBucket).getPublicUrl(path));
    }
    return urls;
  }

  Future<List<String>> uploadEquipmentImageBytes(List<Uint8List> images, String listingId) async {
    final List<String> urls = [];
    for (int i = 0; i < images.length; i++) {
      final path = 'listings/$listingId/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      await _sb.storage
          .from(AppConstants.equipmentBucket)
          .uploadBinary(path, images[i],
              fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));
      urls.add(_sb.storage.from(AppConstants.equipmentBucket).getPublicUrl(path));
    }
    return urls;
  }

  Future<String> uploadProfileImage(File image, String userId) async {
    final path = 'profiles/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final bytes = await image.readAsBytes();
    await _sb.storage
        .from(AppConstants.profileBucket)
        .uploadBinary(path, bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));
    return _sb.storage.from(AppConstants.profileBucket).getPublicUrl(path);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ListingService
// ─────────────────────────────────────────────────────────────────────────────
class ListingService {
  final _storage = StorageService();

  Future<String> createListing(EquipmentListing listing) async {
    final row = await _sb.from('listings').insert(listing.toMap()).select().single();
    return row['id'] as String;
  }

  Future<void> updateListing(String id, Map<String, dynamic> data) async {
    await _sb.from('listings').update(data).eq('id', id);
  }

  Stream<List<EquipmentListing>> getOwnerListings(String ownerId) {
    return _sb
        .from('listings')
        .stream(primaryKey: ['id'])
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(EquipmentListing.fromMap).toList());
  }

  /// Search listings near [lat]/[lng] within [radiusKm]
  Future<List<EquipmentListing>> searchListings({
    required double lat,
    required double lng,
    required double radiusKm,
    String? type,
    double? maxPrice,
    double? minPrice,
    bool? insuranceOnly,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = _sb.from('listings').select().eq('is_active', true);
    if (type != null && type.isNotEmpty) query = query.eq('type', type);
    if (maxPrice != null) query = query.lte('price_per_day', maxPrice);
    if (minPrice != null) query = query.gte('price_per_day', minPrice);
    if (insuranceOnly == true) query = query.eq('insurance_available', true);

    final rows = await query;
    final listings = (rows as List).map((r) => EquipmentListing.fromMap(r)).toList();

    final filtered = listings.where((l) {
      final d = _haversineKm(lat, lng, l.latitude, l.longitude);
      l.distanceKm = d;
      return d <= radiusKm;
    }).toList();

    // Date availability check
    List<EquipmentListing> available = filtered;
    if (startDate != null && endDate != null) {
      final bookingRows = await _sb
          .from('bookings')
          .select('listing_id, start_date, end_date, status')
          .neq('status', 'Declined');
      final bookings = (bookingRows as List).map((r) => BookingModel(
            id: '', listingId: r['listing_id'], listingName: '', listingType: '',
            listingImageUrl: '', farmerId: '', farmerName: '', farmerPhone: '',
            ownerId: '', ownerName: '',
            startDate: DateTime.parse(r['start_date']),
            endDate: DateTime.parse(r['end_date']),
            pricePerDay: 0, totalPrice: 0,
            status: r['status'], createdAt: DateTime.now(),
          )).toList();
      available = filtered.where((l) => l.isAvailableFor(startDate, endDate, bookings)).toList();
    }

    available.sort((a, b) {
      final d = (a.distanceKm ?? 0).compareTo(b.distanceKm ?? 0);
      return d != 0 ? d : b.averageRating.compareTo(a.averageRating);
    });
    return available;
  }

  Future<EquipmentListing?> getListing(String id) async {
    final row = await _sb.from('listings').select().eq('id', id).maybeSingle();
    return row != null ? EquipmentListing.fromMap(row) : null;
  }

  Future<List<String>> uploadImages(List<File> images, String listingId) =>
      _storage.uploadEquipmentImages(images, listingId);

    Future<List<String>> uploadImagesBytes(List<Uint8List> images, String listingId) =>
      _storage.uploadEquipmentImageBytes(images, listingId);

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BookingService — fixed method names: updateStatus() & markCompleted()
// ─────────────────────────────────────────────────────────────────────────────
class BookingService {
  Future<String> createBooking(BookingModel booking) async {
    final row = await _sb.from('bookings').insert(booking.toMap()).select().single();
    return row['id'] as String;
  }

  Stream<List<BookingModel>> getFarmerBookings(String farmerId) {
    return _sb
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('farmer_id', farmerId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(BookingModel.fromMap).toList());
  }

  Stream<List<BookingModel>> getOwnerBookings(String ownerId) {
    return _sb
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(BookingModel.fromMap).toList());
  }

  /// Update booking status — called updateStatus() in Supabase version
  Future<void> updateStatus(
    String bookingId, {
    required String status,
    String? declineReason,
    DateTime? estimatedReturn,
    String? paymentStatus,
  }) async {
    try {
      final rows = await _sb.from('bookings').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
        if (declineReason != null) 'decline_reason': declineReason,
        if (estimatedReturn != null) 'estimated_return': estimatedReturn.toIso8601String(),
        if (paymentStatus != null) 'payment_status': paymentStatus,
      }).eq('id', bookingId).select().maybeSingle();

      if (rows == null) {
        throw Exception('Update failed: no booking found or no permission.');
      }
    } on PostgrestException catch (e) {
      throw Exception('Booking update failed: ${e.message}');
    }
  }

  /// Convenience wrapper
  Future<void> markCompleted(String bookingId) => updateStatus(bookingId, status: AppConstants.statusCompleted);

  Future<bool> hasConflict(String listingId, DateTime start, DateTime end) async {
    final rows = await _sb
        .from('bookings')
        .select('id, start_date, end_date, start_time, end_time, duration_type, status')
        .eq('listing_id', listingId)
        .neq('status', 'Declined');
    for (final r in rows as List) {
      final status = (r['status'] ?? 'Pending') as String;
      if (status == AppConstants.statusDeclined) continue;
      final dur = r['duration_type'] ?? 'full_day';
      if (dur == 'hourly' || r['start_time'] != null || r['end_time'] != null) {
        final existingStart = DateTime.parse(r['start_time'] as String);
        final existingEnd = DateTime.parse(r['end_time'] as String);
        if (!(end.isBefore(existingStart) || start.isAfter(existingEnd))) return true;
      } else {
        final existingStart = DateTime.parse(r['start_date'] as String);
        final existingEnd = DateTime.parse(r['end_date'] as String);
        if (!(end.isBefore(existingStart) || start.isAfter(existingEnd))) return true;
      }
    }
    return false;
  }

  Future<void> cancelBooking(String bookingId, {required String cancelledBy, String? reason}) async {
    await _sb.from('bookings').update({
      'status': AppConstants.statusDeclined,
      'cancelled_by': cancelledBy,
      'cancel_reason': reason,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId);
  }

  Future<void> rescheduleBooking(String bookingId, {
    required DateTime start,
    required DateTime end,
    DateTime? startTime,
    DateTime? endTime,
    String durationType = 'full_day',
  }) async {
    await _sb.from('bookings').update({
      'start_date': start.toIso8601String().split('T').first,
      'end_date': end.toIso8601String().split('T').first,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'duration_type': durationType,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ReviewService
// ─────────────────────────────────────────────────────────────────────────────
class ReviewService {
  Future<void> submitReview(ReviewModel review) async {
    await _sb.from('reviews').insert(review.toMap());
    try {
      await _sb.rpc('update_owner_rating',   params: {'owner_uuid':   review.ownerId});
      await _sb.rpc('update_listing_rating', params: {'listing_uuid': review.listingId});
    } catch (_) {} // RPCs may not exist yet in dev
  }

  Stream<List<ReviewModel>> getListingReviews(String listingId) {
    return _sb
        .from('reviews')
        .stream(primaryKey: ['id'])
        .eq('listing_id', listingId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(ReviewModel.fromMap).toList());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NotificationService
// ─────────────────────────────────────────────────────────────────────────────
class NotificationService {
  Future<void> send({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? referenceId,
  }) async {
    await _sb.from('notifications').insert({
      'user_id': userId, 'title': title, 'body': body,
      'type': type, 'reference_id': referenceId, 'is_read': false,
    });
  }

  Stream<List<AppNotification>> getNotifications(String userId) {
    return _sb
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(AppNotification.fromMap).toList());
  }

  Stream<int> unreadCount(String userId) {
    return _sb
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) => rows.where((r) => r['is_read'] == false).length);
  }

  Future<void> markRead(String id) async {
    await _sb.from('notifications').update({'is_read': true}).eq('id', id);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LocationService
// ─────────────────────────────────────────────────────────────────────────────
class LocationService {
  Future<Position?> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return null;
    }
    if (perm == LocationPermission.deniedForever) return null;
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<String?> getAddressFromCoords(double lat, double lng) async {
    try {
      final p = (await placemarkFromCoordinates(lat, lng)).first;
      return '${p.subLocality ?? ''}, ${p.locality ?? ''}, ${p.administrativeArea ?? ''}'.trim();
    } catch (_) { return null; }
  }
}
