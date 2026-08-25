-- ============================================================
-- CYCLISTIC TRIP DATA — CLEANING
-- Builds trips_clean from trips_raw based on findings from
-- 01_data_exploration.sql. Full reasoning: see README.md
-- ============================================================

CREATE OR REPLACE TABLE `cyclistic-case-study-505614.cyclistic_trips.trips_clean` AS

WITH labeled AS (
  SELECT
    ride_id,
    rideable_type,
    started_at,
    ended_at,
    member_casual,

    -- Electric bikes missing a station name are real rides (confirmed
    -- via coordinates in exploration) — relabeled instead of dropping.
    CASE
      WHEN start_station_name IS NULL AND rideable_type = 'electric_bike'
        THEN 'Not Docked (Electric Bike)'
      ELSE start_station_name
    END AS start_station_name,

    CASE
      WHEN end_station_name IS NULL AND rideable_type = 'electric_bike'
        THEN 'Not Docked (Electric Bike)'
      ELSE end_station_name
    END AS end_station_name,

    start_lat,
    start_lng,
    end_lat,
    end_lng,

    TIMESTAMP_DIFF(ended_at, started_at, MINUTE) AS ride_length_minutes,
    EXTRACT(DAYOFWEEK FROM started_at) AS day_of_week,
    FORMAT_TIMESTAMP('%A', started_at) AS day_of_week_name,
    EXTRACT(MONTH FROM started_at) AS ride_month,
    FORMAT_TIMESTAMP('%B', started_at) AS ride_month_name,
    EXTRACT(HOUR FROM started_at) AS start_hour

  FROM `cyclistic-case-study-505614.cyclistic_trips.trips_raw`
)

SELECT *
FROM labeled
WHERE
  -- Remove negative, sub-1-minute, and 24hr+ rides
  ride_length_minutes > 1
  AND ride_length_minutes < 1440

  -- Remove classic bikes still missing a station name (real errors)
  AND NOT (rideable_type = 'classic_bike' AND start_station_name IS NULL)
  AND NOT (rideable_type = 'classic_bike' AND end_station_name IS NULL)

  -- Every remaining ride should have full coordinates
  AND start_lat IS NOT NULL
  AND start_lng IS NOT NULL
  AND end_lat IS NOT NULL
  AND end_lng IS NOT NULL;


-- Before/after row count for documentation
SELECT
  (SELECT COUNT(*) FROM `cyclistic-case-study-505614.cyclistic_trips.trips_raw`) AS raw_row_count,
  (SELECT COUNT(*) FROM `cyclistic-case-study-505614.cyclistic_trips.trips_clean`) AS clean_row_count;
