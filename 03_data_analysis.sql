-- ============================================================
-- CYCLISTIC TRIP DATA — ANALYSIS
-- Table: cyclistic-case-study-505614.cyclistic_trips.trips_clean
-- Answers the business question: how do casual riders and
-- members use Cyclistic differently?
-- ============================================================


-- 1. Overall descriptive stats
SELECT
  ROUND(AVG(ride_length_minutes), 2) AS avg_ride_minutes,
  MAX(ride_length_minutes) AS max_ride_minutes,
  MIN(ride_length_minutes) AS min_ride_minutes
FROM `cyclistic-case-study-505614.cyclistic_trips.trips_clean`;


-- 2. Average ride length: members vs casual riders
SELECT
  member_casual,
  ROUND(AVG(ride_length_minutes), 2) AS avg_ride_minutes,
  COUNT(*) AS num_rides
FROM `cyclistic-case-study-505614.cyclistic_trips.trips_clean`
GROUP BY member_casual
ORDER BY member_casual;


-- 3. Rides and average length by day of week, split by rider type
SELECT
  member_casual,
  day_of_week,
  day_of_week_name,
  COUNT(*) AS num_rides,
  ROUND(AVG(ride_length_minutes), 2) AS avg_ride_minutes
FROM `cyclistic-case-study-505614.cyclistic_trips.trips_clean`
GROUP BY member_casual, day_of_week, day_of_week_name
ORDER BY member_casual, day_of_week;


-- 4. Rides and average length by month, split by rider type (seasonality)
SELECT
  member_casual,
  ride_month,
  ride_month_name,
  COUNT(*) AS num_rides,
  ROUND(AVG(ride_length_minutes), 2) AS avg_ride_minutes
FROM `cyclistic-case-study-505614.cyclistic_trips.trips_clean`
GROUP BY member_casual, ride_month, ride_month_name
ORDER BY member_casual, ride_month;


-- 5. Rides by hour of day, split by rider type (commute vs. leisure)
SELECT
  member_casual,
  start_hour,
  COUNT(*) AS num_rides
FROM `cyclistic-case-study-505614.cyclistic_trips.trips_clean`
GROUP BY member_casual, start_hour
ORDER BY member_casual, start_hour;


-- 6. Bike type preference by rider type (percentage)
SELECT
  member_casual,
  rideable_type,
  COUNT(*) AS num_rides,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY member_casual), 1) AS pct_of_rider_type
FROM `cyclistic-case-study-505614.cyclistic_trips.trips_clean`
GROUP BY member_casual, rideable_type
ORDER BY member_casual, num_rides DESC;


-- 7. Weekday vs weekend comparison
SELECT
  member_casual,
  CASE 
    WHEN day_of_week IN (1, 7) 
      THEN 'Weekend' 
    ELSE 'Weekday' 
  END AS day_type,
  COUNT(*) AS num_rides,
  ROUND(AVG(ride_length_minutes), 2) AS avg_ride_minutes
FROM `cyclistic-case-study-505614.cyclistic_trips.trips_clean`
GROUP BY member_casual, day_type
ORDER BY member_casual, day_type;


-- 8. Top 10 most popular start stations, by rider type
-- Excludes the electric-bike "Not Docked" placeholder so ranking
-- reflects real named stations only.
WITH ranked_stations AS (
  SELECT
    member_casual,
    start_station_name,
    COUNT(*) AS num_rides,
    RANK() OVER (
      PARTITION BY member_casual
      ORDER BY COUNT(*) DESC
    ) AS station_rank
  FROM `cyclistic-case-study-505614.cyclistic_trips.trips_clean`
  WHERE start_station_name != 'Not Docked (Electric Bike)'
  GROUP BY member_casual, start_station_name
)

SELECT *
FROM ranked_stations
WHERE station_rank <= 10
ORDER BY member_casual, station_rank;

-- 9. Ride start location density, by rider type 
SELECT
  ROUND(start_lat, 3) AS grid_lat,
  ROUND(start_lng, 3) AS grid_lng,
  member_casual,
  COUNT(*) AS num_rides
FROM `cyclistic-case-study-505614.cyclistic_trips.trips_clean`
GROUP BY grid_lat, grid_lng, member_casual
ORDER BY num_rides DESC;

-- 10. Ride end location density, by rider type 
SELECT
  member_casual,
  ROUND(end_lat, 3) AS grid_lat,
  ROUND(end_lng, 3) AS grid_lng,
  COUNT(*) AS num_rides
FROM `cyclistic-case-study-505614.cyclistic_trips.trips_clean`
WHERE end_lat IS NOT NULL
  AND end_lng IS NOT NULL
GROUP BY member_casual, grid_lat, grid_lng
ORDER BY num_rides DESC;