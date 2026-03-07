// ─────────────────────────────────────────────────────────────────────────────
// Models — Supabase edition (snake_case Postgres columns)
// ─────────────────────────────────────────────────────────────────────────────

// ── UserModel ────────────────────────────────────────────────────────────────
class UserModel {
  final String id;           // UUID — use .id everywhere (NOT .uid)
  final String name;
  final String email;
  final String phone;
  final String role;         // farmer | owner | admin
  final String? profileImageUrl;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double averageRating;
  final int totalReviews;
  final DateTime createdAt;
  final bool isVerified;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.profileImageUrl,
    this.address,
    this.latitude,
    this.longitude,
    this.averageRating = 0.0,
    this.totalReviews = 0,
    required this.createdAt,
    this.isVerified = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> m) => UserModel(
        id: m['id'] as String,
        name: m['name'] ?? '',
        email: m['email'] ?? '',
        phone: m['phone'] ?? '',
        role: m['role'] ?? 'farmer',
        profileImageUrl: m['profile_image_url'],
        address: m['address'],
        latitude: (m['latitude'] as num?)?.toDouble(),
        longitude: (m['longitude'] as num?)?.toDouble(),
        averageRating: (m['average_rating'] as num?)?.toDouble() ?? 0.0,
        totalReviews: m['total_reviews'] ?? 0,
        createdAt: DateTime.parse(m['created_at'] as String),
        isVerified: m['is_verified'] ?? false,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'profile_image_url': profileImageUrl,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'average_rating': averageRating,
        'total_reviews': totalReviews,
        'is_verified': isVerified,
      };
}

// ── EquipmentListing ──────────────────────────────────────────────────────────
// NOTE: Uses latitude/longitude doubles — NO GeoPoint (that was Firebase)
class EquipmentListing {
  final String id;
  final String ownerId;
  final String ownerName;
  final String ownerPhone;
  final double ownerRating;
  final String name;
  final String description;
  final String type;
  final double pricePerDay;
  final List<String> imageUrls;
  final double latitude;
  final double longitude;
  final String address;
  final bool isActive;
  final double averageRating;
  final int totalBookings;
  final DateTime createdAt;
  double? distanceKm;

  EquipmentListing({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.ownerPhone,
    required this.ownerRating,
    required this.name,
    required this.description,
    required this.type,
    required this.pricePerDay,
    required this.imageUrls,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.isActive = true,
    this.averageRating = 0.0,
    this.totalBookings = 0,
    required this.createdAt,
    this.distanceKm,
  });

  factory EquipmentListing.fromMap(Map<String, dynamic> m) => EquipmentListing(
        id: m['id'] as String,
        ownerId: m['owner_id'] as String,
        ownerName: m['owner_name'] ?? '',
        ownerPhone: m['owner_phone'] ?? '',
        ownerRating: (m['owner_rating'] as num?)?.toDouble() ?? 0.0,
        name: m['name'] ?? '',
        description: m['description'] ?? '',
        type: m['type'] ?? '',
        pricePerDay: (m['price_per_day'] as num).toDouble(),
        imageUrls: List<String>.from(m['image_urls'] ?? []),
        latitude: (m['latitude'] as num).toDouble(),
        longitude: (m['longitude'] as num).toDouble(),
        address: m['address'] ?? '',
        isActive: m['is_active'] ?? true,
        averageRating: (m['average_rating'] as num?)?.toDouble() ?? 0.0,
        totalBookings: m['total_bookings'] ?? 0,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'owner_id': ownerId,
        'owner_name': ownerName,
        'owner_phone': ownerPhone,
        'owner_rating': ownerRating,
        'name': name,
        'description': description,
        'type': type,
        'price_per_day': pricePerDay,
        'image_urls': imageUrls,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'is_active': isActive,
        'average_rating': averageRating,
        'total_bookings': totalBookings,
      };

  /// Check availability against a list of existing non-declined bookings
  bool isAvailableFor(DateTime start, DateTime end, List<BookingModel> bookings) {
    final relevant = bookings.where((b) => b.listingId == id);
    for (final b in relevant) {
      if (!(end.isBefore(b.startDate) || start.isAfter(b.endDate))) {
        return false;
      }
    }
    return true;
  }
}

// ── BookingModel ──────────────────────────────────────────────────────────────
class BookingModel {
  final String id;
  final String listingId;
  final String listingName;
  final String listingType;
  final String listingImageUrl;
  final String farmerId;
  final String farmerName;
  final String farmerPhone;
  final String ownerId;
  final String ownerName;
  final DateTime startDate;
  final DateTime endDate;
  final double pricePerDay;
  final double totalPrice;
  final String status;
  final String? usageDetails;
  final String? declineReason;
  final DateTime createdAt;
  final DateTime? updatedAt;

  BookingModel({
    required this.id,
    required this.listingId,
    required this.listingName,
    required this.listingType,
    required this.listingImageUrl,
    required this.farmerId,
    required this.farmerName,
    required this.farmerPhone,
    required this.ownerId,
    required this.ownerName,
    required this.startDate,
    required this.endDate,
    required this.pricePerDay,
    required this.totalPrice,
    required this.status,
    this.usageDetails,
    this.declineReason,
    required this.createdAt,
    this.updatedAt,
  });

  int get durationDays => endDate.difference(startDate).inDays + 1;

  factory BookingModel.fromMap(Map<String, dynamic> m) => BookingModel(
        id: m['id'] as String,
        listingId: m['listing_id'] as String,
        listingName: m['listing_name'] ?? '',
        listingType: m['listing_type'] ?? '',
        listingImageUrl: m['listing_image_url'] ?? '',
        farmerId: m['farmer_id'] as String,
        farmerName: m['farmer_name'] ?? '',
        farmerPhone: m['farmer_phone'] ?? '',
        ownerId: m['owner_id'] as String,
        ownerName: m['owner_name'] ?? '',
        startDate: DateTime.parse(m['start_date'] as String),
        endDate: DateTime.parse(m['end_date'] as String),
        pricePerDay: (m['price_per_day'] as num).toDouble(),
        totalPrice: (m['total_price'] as num).toDouble(),
        status: m['status'] ?? 'Pending',
        usageDetails: m['usage_details'],
        declineReason: m['decline_reason'],
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: m['updated_at'] != null ? DateTime.parse(m['updated_at'] as String) : null,
      );

  Map<String, dynamic> toMap() => {
        'listing_id': listingId,
        'listing_name': listingName,
        'listing_type': listingType,
        'listing_image_url': listingImageUrl,
        'farmer_id': farmerId,
        'farmer_name': farmerName,
        'farmer_phone': farmerPhone,
        'owner_id': ownerId,
        'owner_name': ownerName,
        'start_date': startDate.toIso8601String().split('T').first,
        'end_date': endDate.toIso8601String().split('T').first,
        'price_per_day': pricePerDay,
        'total_price': totalPrice,
        'status': status,
        'usage_details': usageDetails,
        'decline_reason': declineReason,
      };
}

// ── ReviewModel ───────────────────────────────────────────────────────────────
class ReviewModel {
  final String id;
  final String bookingId;
  final String listingId;
  final String farmerId;
  final String farmerName;
  final String ownerId;
  final double rating;
  final String comment;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.bookingId,
    required this.listingId,
    required this.farmerId,
    required this.farmerName,
    required this.ownerId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ReviewModel.fromMap(Map<String, dynamic> m) => ReviewModel(
        id: m['id'] as String,
        bookingId: m['booking_id'] as String,
        listingId: m['listing_id'] as String,
        farmerId: m['farmer_id'] as String,
        farmerName: m['farmer_name'] ?? '',
        ownerId: m['owner_id'] as String,
        rating: (m['rating'] as num).toDouble(),
        comment: m['comment'] ?? '',
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'booking_id': bookingId,
        'listing_id': listingId,
        'farmer_id': farmerId,
        'farmer_name': farmerName,
        'owner_id': ownerId,
        'rating': rating,
        'comment': comment,
      };
}

// ── AppNotification ───────────────────────────────────────────────────────────
class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final String? referenceId;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.referenceId,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        title: m['title'] ?? '',
        body: m['body'] ?? '',
        type: m['type'] ?? '',
        referenceId: m['reference_id'],
        isRead: m['is_read'] ?? false,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'title': title,
        'body': body,
        'type': type,
        'reference_id': referenceId,
        'is_read': isRead,
      };
}
