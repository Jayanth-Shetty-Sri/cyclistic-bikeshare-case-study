-- ============================================================
-- CYCLISTIC TRIP DATA — DATA EXPLORATION
-- Table: cyclistic-case-study-505614.cyclistic_trips.trips_raw
--
-- Before cleaning anything, we look at the raw data four ways:
--   A. Are there duplicate records?
--   B. Is anything missing that shouldn't be?
--   C. Are any values out of a sensible range?
--   D. Are category/label fields consistent?
-- Findings from each section are noted in comments, and feed
-- directly into the decisions made in the cleaning script
-- (cyclistic_cleaning.sql).
-- ============================================================


-- ------------------------------------------------------------
-- A. DUPLICATES
-- Every trip should have its own unique ride_id. If the same
-- ride_id shows up more than once, something got loaded twice.
-- ------------------------------------------------------------

SELECT ride_id, COUNT(*) AS times_seen
FROM `cyclistic-case-study-505614.cyclistic_trips.trips_raw`
GROUP BY ride_id
HAVING times_seen > 1;

-- ride_id should always be the same character length. A mismatch
-- would suggest a formatting problem somewhere.
SELECT LENGTH(ride_id) AS id_char_count, COUNT(*) AS how_many
FROM `cyclistic-case-study-505614.cyclistic_trips.trips_raw`
GROUP BY id_char_count;

-- FINDING: No duplicate ride_ids found. All ride_ids are the same
-- length. This table needed no deduplication.


-- ------------------------------------------------------------
-- B. MISSING DATA
-- Some fields should never be blank (coordinates). Others are
-- only sometimes blank for a legitimate reason (station name,
-- since electric bikes can be locked away from a dock).
-- ------------------------------------------------------------

-- Coordinates: every ride needs a location, no exceptions.
SELECT COUNT(*) AS rides_missing_coordinates
FROM `cyclistic-case-study-505614.cyclistic_trips.trips_raw`
WHERE start_lat IS NULL OR start_lng IS NULL
   OR end_lat IS NULL OR end_lng IS NULL;

-- Station names: break this down by bike type, since a missing
-- station may be expected for electric bikes but not classic ones.
SELECT
  rideable_type,
  COUNT(*) AS total_rides,
  COUNTIF(start_station_name IS NULL) AS missing_start_station,
  COUNTIF(end_station_name IS NULL) AS missing_end_station
FROM `cyclistic-case-study-505614.cyclistic_trips.trips_raw`
GROUP BY rideable_type;

-- FINDING: classic_bike had 1,948,041 total rides, with 0 missing
-- start stations and 5,633 missing end stations (~0.3%) — a small
-- number consistent with occasional data errors.
-- electric_bike had 3,604,953 total rides, with ~1.18-1.24 million
-- missing start/end stations (~33%) — far too large and systematic
-- to be a data error.

-- Follow-up: do electric bike rows with a missing station name
-- still have valid coordinates? If yes, this confirms the bike was
-- genuinely locked at a real (non-station) location rather than the
-- record being broken.
SELECT
  COUNT(*) AS electric_rides_missing_station,
  COUNTIF(start_lat IS NOT NULL AND start_lng IS NOT NULL) AS still_has_start_coordinates,
  COUNTIF(end_lat IS NOT NULL AND end_lng IS NOT NULL) AS still_has_end_coordinates
FROM `cyclistic-case-study-505614.cyclistic_trips.trips_raw`
WHERE rideable_type = 'electric_bike'
  AND (start_station_name IS NULL OR end_station_name IS NULL);

-- FINDING: All 1,854,107 affected electric bike rows still have full
-- start and end coordinates. This confirms these are real rides where
-- the bike was locked at a valid GPS location that just isn't a named
-- docking station — not a data quality problem. These rows should be
-- KEPT in the clean dataset, with the null station name relabeled
-- rather than the row being dropped.

-- Also checked: station names for maintenance/test/warehouse entries,
-- across BOTH start and end fields (some reference analyses of this
-- same dataset found these; worth checking rather than assuming).
SELECT DISTINCT start_station_name AS suspect_station_name, 'start' AS found_in
FROM `cyclistic-case-study-505614.cyclistic_trips.trips_raw`
WHERE LOWER(start_station_name) LIKE '%test%'
   OR LOWER(start_station_name) LIKE '%repair%'
   OR LOWER(start_station_name) LIKE '%warehouse%'

UNION DISTINCT

SELECT DISTINCT end_station_name AS suspect_station_name, 'end' AS found_in
FROM `cyclistic-case-study-505614.cyclistic_trips.trips_raw`
WHERE LOWER(end_station_name) LIKE '%test%'
   OR LOWER(end_station_name) LIKE '%repair%'
   OR LOWER(end_station_name) LIKE '%warehouse%';

-- FINDING: No maintenance/test/warehouse station names found in this
-- dataset, in either field. No filtering needed for this issue.


-- ------------------------------------------------------------
-- C. OUT-OF-RANGE VALUES
-- Ride duration is the main thing to sanity-check: anything
-- basically instant (under a minute) or absurdly long (over a
-- day) is more likely a data glitch than a real trip.
-- ------------------------------------------------------------

SELECT
  COUNTIF(TIMESTAMP_DIFF(ended_at, started_at, MINUTE) < 1) AS under_one_minute,
  COUNTIF(TIMESTAMP_DIFF(ended_at, started_at, MINUTE) > 1440) AS over_one_day,
  COUNT(*) AS total_rides
FROM `cyclistic-case-study-505614.cyclistic_trips.trips_raw`;

-- FINDING: out of 5,552,994 total rides — 147,401 under one minute
-- (~2.7%), 5,585 over one day (~0.1%).

-- Break the short-ride group down by rider/bike type.
SELECT
  member_casual,
  rideable_type,
  COUNT(*) AS num_short_rides
FROM `cyclistic-case-study-505614.cyclistic_trips.trips_raw`
WHERE TIMESTAMP_DIFF(ended_at, started_at, MINUTE) < 1
GROUP BY member_casual, rideable_type
ORDER BY num_short_rides DESC;

-- FINDING: short rides are almost entirely electric bikes
-- (79,009 casual + 68,380 member = 147,389 of 147,401 total).
-- Classic bikes account for only 12 short rides combined. This is
-- a bike-type-specific pattern, not a rider-type-specific one — it
-- is not explained by the case study materials or by this dataset
-- alone. A possible contributing factor, based on Divvy's own
-- published rider documentation
-- (https://help.divvybikes.com/hc/en-us/articles/360033122072-How-to-dock-a-bike):
-- electric bikes can be locked and unlocked independently of a
-- docking station, using a built-in cable lock, which may make it
-- easier to end a ride within seconds of starting it. This is
-- offered as context, not a confirmed cause.

-- Break the long-ride group down the same way.
SELECT
  member_casual,
  rideable_type,
  COUNT(*) AS num_long_rides
FROM `cyclistic-case-study-505614.cyclistic_trips.trips_raw`
WHERE TIMESTAMP_DIFF(ended_at, started_at, MINUTE) > 1440
GROUP BY member_casual, rideable_type
ORDER BY num_long_rides DESC;

-- FINDING: long rides (>1 day) on classic bikes are dominated by
-- casual riders (4,677) vs. members (908) — roughly 84% of these
-- outliers are casual riders. This looks like a genuine behavioral
-- pattern (casual riders more likely to keep a bike out for an
-- extended period, whether intentionally or by forgetting to return
-- it) rather than random data error, and is worth reporting as a
-- finding in the analysis, not just quietly filtered away.

-- Check for negative durations (ended_at earlier than started_at) 
-- unlike short/long rides, this is an unambiguous data error.
SELECT COUNT(*) AS negative_duration_rides
FROM `cyclistic-case-study-505614.cyclistic_trips.trips_raw`
WHERE TIMESTAMP_DIFF(ended_at, started_at, MINUTE) < 0;

-- FINDING: 29 rows with a negative ride duration. Clear data errors,
-- safe to remove with no further interpretation needed.


-- ------------------------------------------------------------
-- D. LABEL CONSISTENCY
-- Category-style fields (bike type, rider type) should only
-- contain the values we expect. Anything extra is either a typo,
-- a formatting inconsistency, or a maintenance/test record.
-- ------------------------------------------------------------

SELECT rideable_type, COUNT(*) AS num_rides
FROM `cyclistic-case-study-505614.cyclistic_trips.trips_raw`
GROUP BY rideable_type;

SELECT member_casual, COUNT(*) AS num_rides
FROM `cyclistic-case-study-505614.cyclistic_trips.trips_raw`
GROUP BY member_casual;

-- FINDING: only expected values found in both columns
-- (classic_bike / electric_bike, and member / casual).
-- No relabeling or standardization needed.
