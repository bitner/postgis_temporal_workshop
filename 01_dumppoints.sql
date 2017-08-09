SELECT now();
SET TIME ZONE 'Europe/Rome';
SELECT now();

SET TIME ZONE 'UTC';
SELECT now();

SET TIME ZONE 'PST8PDT';
SELECT now();

SET TIME ZONE DEFAULT;
SHOW TIME ZONE;
SELECT now();

SELECT timezone('UTC', now());

SELECT '2017-01-01 00:00-6'::timestamptz;
SELECT '2017-01-01'::timestamptz;

SELECT '4/5/2017'::timestamptz;

SET datestyle to dmy;
SELECT '4/5/2017'::timestamptz;

SET datestyle TO DEFAULT;
SELECT '4/5/2017'::timestamptz;

SELECT '1 day'::interval;
SELECT '2016-01-01'::timestamptz + '3 months'::interval;

SELECT to_timestamp(0);

SELECT timezone('UTC',to_timestamp(0));

SELECT extract(epoch from '2017-01-01'::timestamptz);

CREATE FUNCTION to_epoch(IN timestamptz, OUT float8) AS $$
    SELECT extract(epoch from $1);
$$ LANGUAGE SQL;

SELECT to_epoch('2017-01-01'::timestamptz);

SELECT date_trunc('month', now());

SELECT '4713-01-01 BC'::timestamptz;
SELECT '4714-01-01 BC'::timestamptz;

SELECT '294276-01-01'::timestamptz;
SELECT '294277-01-01'::timestamptz;

SELECT st_dumppoints(geom) FROM superior100 limit 10;
SELECT (st_dumppoints(geom)).* FROM superior100 limit 10;

WITH t AS (SELECT st_dumppoints(geom) as dump FROM superior100)
SELECT 
    (dump).path[1],
    st_asewkt((dump).geom), 
    st_x((dump).geom), 
    st_y((dump).geom)
FROM t 
LIMIT 10;

DROP TABLE IF EXISTS superior100_points;
CREATE TABLE superior100_points AS 
WITH t AS (SELECT st_dumppoints(geom) as dump FROM superior100)
SELECT 
    (dump).path[1],
    (dump).geom, 
    st_x((dump).geom) as x, 
    st_y((dump).geom) as y
FROM t;

ALTER TABLE superior100_points ADD COLUMN z float8;

UPDATE superior100_points 
SET 
    z=st_value(rast,geom) 
FROM dem 
WHERE st_intersects(dem.rast,geom);

SELECT st_asewkt(geom), x, y, z FROM superior100_points LIMIT 10;

UPDATE superior100_points SET geom = st_setsrid(st_makepoint(x,y,z), 26915);

SELECT st_asewkt(geom) FROM superior100_points LIMIT 10;

WITH t AS (SELECT * FROM superior100_points ORDER BY PATH)
SELECT substring(st_asewkt(st_makeline(geom)),1,200) FROM t;

SELECT path, x, y, z, z-lag(z) OVER (ORDER BY PATH) FROM superior100_points LIMIT 20;

ALTER TABLE superior100_points ADD COLUMN elchange float8;

WITH t AS (SELECT path, x, y, z, z-lag(z) OVER (ORDER BY PATH) elchange FROM superior100_points)
UPDATE superior100_points p SET elchange=t.elchange FROM t WHERE p.path=t.path;

SELECT x, y, z, elchange FROM superior100_points limit 10;

SELECT 
    3.28 * sum(elchange) FILTER (WHERE elchange>0) as gain, 
    3.28 * sum(elchange) FILTER (WHERE elchange<0) as descent 
FROM superior100_points;

SELECT path, x, y, z, degrees(st_azimuth(lag(geom) OVER (ORDER BY path), geom)) FROM superior100_points LIMIT 20;




-- Comment