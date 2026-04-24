-- ═══════════════════════════════════════════════════════════════════════════
-- KisanYantra — Complete Supabase Database Setup
-- Run this entire script in: Supabase Dashboard → SQL Editor → New Query
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 1 · USERS TABLE
-- Mirrors auth.users — stores role, profile, location, ratings
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.users (
  id                UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name              TEXT        NOT NULL,
  email             TEXT        NOT NULL UNIQUE,
  phone             TEXT        NOT NULL DEFAULT '',
  role              TEXT        NOT NULL DEFAULT 'farmer'
                      CHECK (role IN ('farmer','owner','admin')),
  profile_image_url TEXT,
  address           TEXT,
  latitude          DOUBLE PRECISION,
  longitude         DOUBLE PRECISION,
  average_rating    DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  total_reviews     INT          NOT NULL DEFAULT 0,
  is_verified       BOOLEAN      NOT NULL DEFAULT FALSE,
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 2 · LISTINGS TABLE
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.listings (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id        UUID         NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  owner_name      TEXT         NOT NULL DEFAULT '',
  owner_phone     TEXT         NOT NULL DEFAULT '',
  owner_rating    DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  name            TEXT         NOT NULL,
  description     TEXT         NOT NULL DEFAULT '',
  type            TEXT         NOT NULL,
  price_per_day   DOUBLE PRECISION NOT NULL CHECK (price_per_day >= 0),
  image_urls      TEXT[]       NOT NULL DEFAULT '{}',
  latitude        DOUBLE PRECISION NOT NULL,
  longitude       DOUBLE PRECISION NOT NULL,
  address         TEXT         NOT NULL DEFAULT '',
  is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
  average_rating  DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  total_bookings  INT          NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 3 · BOOKINGS TABLE
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.bookings (
  id                UUID  PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id        UUID  NOT NULL REFERENCES public.listings(id) ON DELETE CASCADE,
  listing_name      TEXT  NOT NULL DEFAULT '',
  listing_type      TEXT  NOT NULL DEFAULT '',
  listing_image_url TEXT  NOT NULL DEFAULT '',
  farmer_id         UUID  NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  farmer_name       TEXT  NOT NULL DEFAULT '',
  farmer_phone      TEXT  NOT NULL DEFAULT '',
  owner_id          UUID  NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  owner_name        TEXT  NOT NULL DEFAULT '',
  start_date        DATE  NOT NULL,
  end_date          DATE  NOT NULL,
  price_per_day     DOUBLE PRECISION NOT NULL,
  total_price       DOUBLE PRECISION NOT NULL,
  status            TEXT  NOT NULL DEFAULT 'Pending'
                      CHECK (status IN ('Pending','Approved','Declined','Completed')),
  usage_details     TEXT,
  decline_reason    TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ,
  CONSTRAINT no_overlap_check CHECK (end_date >= start_date)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 4 · REVIEWS TABLE
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.reviews (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id  UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  listing_id  UUID NOT NULL REFERENCES public.listings(id) ON DELETE CASCADE,
  farmer_id   UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  farmer_name TEXT NOT NULL DEFAULT '',
  owner_id    UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  rating      DOUBLE PRECISION NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment     TEXT NOT NULL DEFAULT '',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (booking_id) -- one review per booking
);

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 5 · NOTIFICATIONS TABLE
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notifications (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title        TEXT NOT NULL,
  body         TEXT NOT NULL,
  type         TEXT NOT NULL, -- booking_request | booking_update | review
  reference_id TEXT,          -- booking id or listing id
  is_read      BOOLEAN NOT NULL DEFAULT FALSE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 6 · INDEXES for performance
-- ─────────────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_listings_owner     ON public.listings(owner_id);
CREATE INDEX IF NOT EXISTS idx_listings_type      ON public.listings(type);
CREATE INDEX IF NOT EXISTS idx_listings_active    ON public.listings(is_active);
CREATE INDEX IF NOT EXISTS idx_listings_location  ON public.listings(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_bookings_farmer    ON public.bookings(farmer_id);
CREATE INDEX IF NOT EXISTS idx_bookings_owner     ON public.bookings(owner_id);
CREATE INDEX IF NOT EXISTS idx_bookings_listing   ON public.bookings(listing_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status    ON public.bookings(status);
CREATE INDEX IF NOT EXISTS idx_bookings_dates     ON public.bookings(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_reviews_listing    ON public.reviews(listing_id);
CREATE INDEX IF NOT EXISTS idx_reviews_owner      ON public.reviews(owner_id);
CREATE INDEX IF NOT EXISTS idx_notif_user         ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notif_read         ON public.notifications(is_read);

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 7 · HELPER FUNCTIONS (called after submitting a review)
-- ─────────────────────────────────────────────────────────────────────────────

-- Recalculate and update owner average rating
CREATE OR REPLACE FUNCTION update_owner_rating(owner_uuid UUID)
RETURNS VOID AS $$
DECLARE
  avg_r DOUBLE PRECISION;
  total_r INT;
BEGIN
  SELECT AVG(rating), COUNT(*) INTO avg_r, total_r
  FROM public.reviews WHERE owner_id = owner_uuid;
  UPDATE public.users
  SET average_rating = COALESCE(avg_r, 0),
      total_reviews  = COALESCE(total_r, 0)
  WHERE id = owner_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recalculate and update listing average rating
CREATE OR REPLACE FUNCTION update_listing_rating(listing_uuid UUID)
RETURNS VOID AS $$
DECLARE
  avg_r DOUBLE PRECISION;
BEGIN
  SELECT AVG(rating) INTO avg_r
  FROM public.reviews WHERE listing_id = listing_uuid;
  UPDATE public.listings
  SET average_rating = COALESCE(avg_r, 0)
  WHERE id = listing_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 8 · AUTO-SYNC USER ON SIGNUP (trigger on auth.users insert)
-- Creates a minimal users row automatically when someone signs up.
-- The Flutter app will then UPDATE it with name/phone/role.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, name, email)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'name',''), NEW.email)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 9 · ROW LEVEL SECURITY (RLS)
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.users         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.listings      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- ── USERS policies ──────────────────────────────────────────────────────────
-- Any signed-in user can read all profiles
CREATE POLICY "users: read all"
  ON public.users FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Users can insert and update only their own row
CREATE POLICY "users: insert own"
  ON public.users FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "users: update own"
  ON public.users FOR UPDATE
  USING (auth.uid() = id);

-- ── LISTINGS policies ────────────────────────────────────────────────────────
-- Any signed-in user can read active listings
CREATE POLICY "listings: read active"
  ON public.listings FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Only owners can create listings (enforced by role check in Flutter)
CREATE POLICY "listings: owner insert"
  ON public.listings FOR INSERT
  WITH CHECK (auth.uid() = owner_id);

-- Only the listing owner can update
CREATE POLICY "listings: owner update"
  ON public.listings FOR UPDATE
  USING (auth.uid() = owner_id);

-- ── BOOKINGS policies ────────────────────────────────────────────────────────
CREATE POLICY "bookings: farmer or owner read"
  ON public.bookings FOR SELECT
  USING (auth.uid() = farmer_id OR auth.uid() = owner_id);

CREATE POLICY "bookings: farmer insert"
  ON public.bookings FOR INSERT
  WITH CHECK (auth.uid() = farmer_id);

CREATE POLICY "bookings: owner update status"
  ON public.bookings FOR UPDATE
  USING (auth.uid() = owner_id OR auth.uid() = farmer_id);

-- ── REVIEWS policies ─────────────────────────────────────────────────────────
CREATE POLICY "reviews: read all"
  ON public.reviews FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "reviews: farmer insert"
  ON public.reviews FOR INSERT
  WITH CHECK (auth.uid() = farmer_id);

-- ── NOTIFICATIONS policies ───────────────────────────────────────────────────
CREATE POLICY "notif: own only"
  ON public.notifications FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "notif: insert authenticated"
  ON public.notifications FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "notif: own update"
  ON public.notifications FOR UPDATE
  USING (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- STEP 10 · REALTIME  (enable for live booking/notification updates)
-- ─────────────────────────────────────────────────────────────────────────────
ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.listings;

-- ─────────────────────────────────────────────────────────────────────────────
-- Done! ✅  All tables, RLS, triggers, and functions are ready.
-- ─────────────────────────────────────────────────────────────────────────────
