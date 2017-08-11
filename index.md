# Breaking the 4th dimension: working with time in PostgreSQL and PostGIS

---

<img src="https://pbs.twimg.com/profile_images/779351896817602562/YXf-qdul.jpg" width="400px"></img>

---
### David Bitner dbitner@boundlessgeo.com
Senior Development Engineer - Boundless Spatial
<img src='https://boundlessgeo.com/wp-content/themes/boundlessgeo/assets/images/BoundlessLogoTag.svg' width='400px'></img>

---

The goal of this workshop is to walk through several examples of how to use 3rd and 4th dimension data with PostgreSQL and PostGIS with a particular emphasis on using M values with points and linestrings.

---
# Agenda
* Time Basics
* Elevation, Points<->Lines
* Tracks
---
<notes>
PostgreSQL has very extensive support for temporal data using the Timestamp, TimestampTZ, Date, Time, TimeTZ, and Interval data types. PostgreSQL is very forgiving as to how data can be input as plain text.

It should be noted that in almost all cases it is better to use the Time Zone aware TimestampTZ and TimeTZ data types as the non timezone aware Timestamp and Time can be lossy and ambiguous in most circumstances. 

Further, while PostgreSQL is incredibly tolerant of text data input formats, ISO8601 should be the preferred method for communicating with dates and times. Day/month/year and month/day/year can be particularly problematic as they are each preferred in different parts of the world.
</notes>

### Exercise: Convert different text formats into timestamps

```sql
SELECT '2017-01-01 00:00-6'::timestamptz;

SELECT '2017-01-01'::timestamptz;

SELECT '4/5/2017'::timestamptz;
```
---
<notes>
Day/month/year and month/day/year can be particularly problematic as they are each preferred in different parts of the world.
</notes>

### Exercise: Use session settings to control Timestamp in/out

```sql
SET datestyle to dmy;
SELECT '4/5/2017'::timestamptz;

SET datestyle TO DEFAULT;
SELECT '4/5/2017'::timestamptz;
```
---
<notes>
By using the TimestampTZ data type it becomes easy to view the data in whatever locality is necessary at the moment.
</notes>

### Exercise: Use session settings to control Timezone in/out

```sql
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
```

---

<notes>
PostgreSQL also has an interval type that can maintain periods of time
</notes>

```sql
SELECT '1 day'::interval;
SELECT '2016-01-01'::timestamptz + '3 months'::interval;
```

```sql
SELECT to_timestamp(0);

SELECT timezone('UTC',to_timestamp(0));

SELECT extract(epoch from '2017-01-01'::timestamptz);

SELECT extract(epoch from '1 hour'::interval);
```

```sql

CREATE FUNCTION to_epoch(IN timestamptz, OUT float8) AS $$
    SELECT extract(epoch from $1);
$$ LANGUAGE SQL;

CREATE FUNCTION to_epoch(IN interval, OUT float8) AS $$
    SELECT extract(epoch from $1);
$$ LANGUAGE SQL;

SELECT to_epoch('2017-01-01'::timestamptz);
SELECT to_epoch('1 hour'::interval);
```

```sql

SELECT date_trunc('month', now());
```

```sql

SELECT '4713-01-01 BC'::timestamptz;
SELECT '4714-01-01 BC'::timestamptz;

SELECT '294276-01-01'::timestamptz;
SELECT '294277-01-01'::timestamptz;
```

```sql

SELECT st_dumppoints(geom) FROM superior100 limit 10;
SELECT (st_dumppoints(geom)).* FROM superior100 limit 10;
```

```sql

WITH t AS (SELECT st_dumppoints(geom) as dump FROM superior100)
SELECT 
    (dump).path[1],
    st_asewkt((dump).geom), 
    st_x((dump).geom), 
    st_y((dump).geom)
FROM t 
LIMIT 10;
```

```sql

DROP TABLE IF EXISTS superior100_points;
CREATE TABLE superior100_points AS 
WITH t AS (SELECT st_dumppoints(geom) as dump FROM superior100)
SELECT 
    (dump).path[1],
    (dump).geom, 
    st_x((dump).geom) as x, 
    st_y((dump).geom) as y
FROM t;
```

```sql

ALTER TABLE superior100_points ADD COLUMN z float8;

UPDATE superior100_points 
SET 
    z=round(st_value(rast,geom)::numeric,1)
FROM dem 
WHERE st_intersects(dem.rast,geom);
```

```sql

SELECT st_asewkt(geom), x, y, z FROM superior100_points LIMIT 10;

UPDATE superior100_points SET geom = st_setsrid(st_makepoint(x,y,z), 26915);
```

```sql

SELECT st_asewkt(geom) FROM superior100_points LIMIT 10;

WITH t AS (SELECT * FROM superior100_points ORDER BY PATH)
SELECT substring(st_asewkt(st_makeline(geom)),1,100) FROM t;
```

```sql

CREATE TABLE superior1003d AS
WITH t AS (SELECT * FROM superior100_points ORDER BY PATH)
SELECT st_makeline(geom) as geom FROM t;

SELECT path, x, y, z, z-lag(z) OVER (ORDER BY PATH) FROM superior100_points LIMIT 20;
```

```sql

ALTER TABLE superior100_points ADD COLUMN elchange float8;

WITH t AS (SELECT path, x, y, z, round((z-lag(z) OVER (ORDER BY PATH))::numeric,1) elchange FROM superior100_points)
UPDATE superior100_points p SET elchange=t.elchange FROM t WHERE p.path=t.path;

SELECT x, y, z, elchange FROM superior100_points limit 10;
```

```sql

SELECT 
    3.28 * sum(elchange) FILTER (WHERE elchange>0) as gain, 
    3.28 * sum(elchange) FILTER (WHERE elchange<0) as descent 
FROM superior100_points;
```

```sql

SELECT path, x, y, z, degrees(st_azimuth(lag(geom) OVER (ORDER BY path), geom)) FROM superior100_points LIMIT 20;
```

```sql


SELECT st_length(geom)/1609 FROM superior100;
SELECT st_length(geom)/1609 FROM superior1003d;
SELECT st_3dlength(geom)/1609 FROM superior1003d;
```

```sql


SELECT st_asewkt(st_lineinterpolatepoint(geom,.5)) FROM superior1003d;
SELECT st_asewkt(st_lineinterpolatepoint(geom,50*1609/st_length(geom))) FROM superior1003d;

SELECT
    a.aidstation,
    a.miles,
    a.miles/st_length(s.geom)*1609 as along_track,
    a.miles/103.2 along_total_distance,
    st_linelocatepoint(s.geom,a.geom) at_nearest_point
FROM
    aidstations a,
    superior1003d s
ORDER BY a.miles
;

CREATE TABLE sections AS
SELECT 
    aidstation,
    miles,
    st_addmeasure(
        st_linesubstring(
            s.geom,
            st_linelocatepoint(s.geom,lag(a.geom) OVER (ORDER BY miles)),
            st_linelocatepoint(s.geom,a.geom)
        ),
        lag(a.miles) OVER (ORDER BY miles),
        a.miles
    ) as geom
FROM
    aidstations a,
    superior1003d s
ORDER BY a.miles  
;

SELECT aidstation, miles, substring(st_asewkt(geom),0,100) FROM sections;

CREATE TABLE superior1003dm AS 
SELECT st_linemerge(st_collect(geom)) AS geom FROM sections;

SELECT substring(st_asewkt(geom),0,100) FROM superior1003dm;

DROP TABLE superior1003dm;
CREATE TABLE superior1003dm AS 
WITH 
p1 AS 
    (SELECT (st_dumppoints(geom)).* FROM sections),
p2 AS
    (SELECT geom, st_m(geom) FROM p1 ORDER BY st_m(geom))
SELECT st_makeline(geom) as geom FROM p2;

SELECT substring(st_asewkt(geom),0,100) FROM superior1003dm;

SELECT * FROM superiorsplits ORDER BY runnerid, aidstation LIMIT 20;

SELECT aidstation, min(split), avg(split), max(split) FROM superiorsplits GROUP BY aidstation ORDER BY min(split);

SELECT aidstation, min(split), avg(split), max(split) 
FROM superiorsplits 
WHERE finish BETWEEN '35 hours'::interval AND '37 hours'::interval
GROUP BY aidstation ORDER BY min(split);

CREATE TABLE bitner_goal AS 
WITH 
goalsplits AS (
    SELECT aidstation, avg(split) as goal
    FROM superiorsplits 
    WHERE finish BETWEEN '35 hours'::interval AND '37 hours'::interval
    GROUP BY aidstation ORDER BY min(split)
)
SELECT 
    aidstation,
    miles as miles,
    miles - coalesce(lag(miles) OVER (ORDER BY miles),0) AS miles_section,
    coalesce(lag(goal) OVER (ORDER BY miles),'0 hours'::interval) as goal_from,
    goal as goal_to,
    goal - coalesce(lag(goal) OVER (ORDER BY miles),'0 hours'::interval) AS goal_section,
    '2017-09-08 08:00:00 CDT'::timestamptz + goal AS goal_time,
    (goal - coalesce(lag(goal) OVER (ORDER BY miles),'0 hours'::interval)) 
    /  
    (miles - coalesce(lag(miles) OVER (ORDER BY miles),0))
    as pace_section
FROM
    sections JOIN goalsplits USING (aidstation)
;

SELECT * FROM bitner_goal;

CREATE TABLE bitner_goal_track AS
WITH
t1 AS (
    SELECT 
        st_addmeasure(geom, to_epoch(goal_from), to_epoch(goal_to)) AS geom
    FROM
        sections JOIN bitner_goal USING (aidstation)
),
p1 AS 
    (SELECT (st_dumppoints(geom)).* FROM t1),
p2 AS
    (SELECT DISTINCT ON (st_m(geom)) geom, st_m(geom) FROM p1 ORDER BY st_m(geom))
SELECT st_makeline(geom) as geom FROM p2;

SELECT substring(st_asewkt(geom),0,100) FROM bitner_goal_track;

SELECT * FROM superiorsplits 
WHERE aidstation='finish' AND finish BETWEEN '35.5 hours'::interval AND '36.5 hours'::interval LIMIT 20;

CREATE TABLE target_goal AS 
WITH 
goalsplits AS (
    SELECT aidstation, split as goal
    FROM superiorsplits 
    WHERE runnerid = 93
)
SELECT 
    aidstation,
    miles as miles,
    miles - coalesce(lag(miles) OVER (ORDER BY miles),0) AS miles_section,
    coalesce(lag(goal) OVER (ORDER BY miles),'0 hours'::interval) as goal_from,
    goal as goal_to,
    goal - coalesce(lag(goal) OVER (ORDER BY miles),'0 hours'::interval) AS goal_section,
    '2017-09-08 08:00:00 CDT'::timestamptz + goal AS goal_time,
    (goal - coalesce(lag(goal) OVER (ORDER BY miles),'0 hours'::interval)) 
    /  
    (miles - coalesce(lag(miles) OVER (ORDER BY miles),0))
    as pace_section
FROM
    sections JOIN goalsplits USING (aidstation)
;

SELECT * FROM target_goal;

CREATE TABLE target_goal_track AS
WITH
t1 AS (
    SELECT 
        st_addmeasure(geom, to_epoch(goal_from), to_epoch(goal_to)) AS geom
    FROM
        sections JOIN target_goal USING (aidstation)
),
p1 AS 
    (SELECT (st_dumppoints(geom)).* FROM t1),
p2 AS
    (SELECT DISTINCT ON (st_m(geom)) geom, st_m(geom) FROM p1 ORDER BY st_m(geom))
SELECT st_makeline(geom) as geom FROM p2;

SELECT substring(st_asewkt(geom),0,100) FROM target_goal_track;

SELECT st_isvalidtrajectory(geom) FROM bitner_goal_track;
SELECT st_isvalidtrajectory(geom) FROM target_goal_track;

SELECT (st_closestpointofapproach(
    (SELECT st_linesubstring(geom,.5,1) FROM bitner_goal_track),
    (SELECT st_linesubstring(geom,.5,1) FROM target_goal_track)
)::text || ' seconds')::interval;

SELECT st_distancecpa(
    (SELECT st_linesubstring(geom,.5,1) FROM bitner_goal_track),
    (SELECT st_linesubstring(geom,.5,1) FROM target_goal_track)
);

```
