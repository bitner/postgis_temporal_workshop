# Breaking the 4th dimension: working with time in PostgreSQL and PostGIS
---
<img src="https://pbs.twimg.com/profile_images/779351896817602562/YXf-qdul.jpg" width="400px"></img>
---
### David Bitner dbitner@boundlessgeo.com
Senior Development Engineer - Boundless Spatial
<br></br>
<img src='https://boundlessgeo.com/wp-content/themes/boundlessgeo/assets/images/BoundlessLogoTag.svg' width='400px'></img>
---

The goal of this workshop is to walk through several examples of how to use 3rd and 4th dimension data with PostgreSQL and PostGIS with a particular emphasis on using M values with points and linestrings.

---
<img src="https://lh3.googleusercontent.com/sVulInvyix9Ivdx3NNyka5ZPCNKgEoS9wic_HTEVFKJfLcG-cCkFgwQnTNIbTM59mQ3cHyX1RqIi5KeWlYVqJNsWWy17Pvv99jdaP-F7v1nsz5A-dZeMoTTh_QlWzxvY_SRzgaTY2bTvEGY6jnqKFWxghrpsyH6M3_HtDNPJvl35LVybmQ5v9w4Zers92dTnAjNoQCCpA8CdQufESAWL9eRwOM7Thb0_K4AK1ZWFn5h6BMYJDyqPQo61GVZzv3wsAif-Ltrn4jEG6jC39c1qvA00_jviB880UUp2AbGnICBjvlmRkv5oJl13BiAHVevQsMThP_hCnRRvMmGTd4gdEqM_8TwX11XW3dLmd-B1RsJ3pmMtdQWjQiHHMOvkXMY3T1dqVEkuOhd5Xsy2NZ2EvuDo3dEQjiHjxIqGSo_6rR0Xe15MTHfkYbj9Mv2r0Lb0Cnrjd6qOds9W_2DhAJM9mQpmeGwCjv8jHaaFNrT94g4Rt7AUYRp9u4DD1KyS8968RGuPqsgHEdE7qW1_BHHCFVngLSFFDuF05W17XRulRvpHu_Yhbsk9_xO3qBI5huGZBs39U6mfvXNeMmADlLhdcdHTINg75zGr9-6y0cqWROKielHIZpvaXH1egRQtNVp4SFaZWzF3ftmitpwNQ8qBlKDC0DdqlD5evYA99HkkOWQQn98=w2576-h1449-no" width='500px'></img>


I have a bad habit of entering events where you go to really pretty places to run really far. In just a couple weeks I'll be making my first attempt to run 100 miles on the Superior Hiking Trail overlooking Lake Superior in Northern Minnesota. For the rest of this workshop, we'll use available data from previous years of this race to help setup a pace chart and create tools for my crew to help follow me during the event.

---
# Agenda
* Setup
* Time Basics
* Elevation, Points<->Lines
* Tracks
---
# Setup
```bash
createdb superior
export PGDATABASE=superior
psql -c "CREATE EXTENSION postgis;" superior
psql -c "SELECT postgis_full_version();" superior
```
---
## PostgreSQL Date / Time Datatypes and Functions
* https://www.postgresql.org/docs/9.6/static/datatype-datetime.html
* https://www.postgresql.org/docs/9.6/static/functions-datetime.html
* https://www.postgresql.org/docs/9.6/static/functions-formatting.html


PostgreSQL has very extensive support for temporal data using the Timestamp, TimestampTZ, Date, Time, TimeTZ, and Interval data types. PostgreSQL is very forgiving as to how data can be input as plain text.

It should be noted that in almost all cases it is better to use the Time Zone aware TimestampTZ and TimeTZ data types as the non timezone aware Timestamp and Time can be lossy and ambiguous in most circumstances. 

Further, while PostgreSQL is incredibly tolerant of text data input formats, ISO8601 should be the preferred method for communicating with dates and times. Day/month/year and month/day/year can be particularly problematic as they are each preferred in different parts of the world.


---
<img src="https://imgs.xkcd.com/comics/iso_8601.png" width='500px'></img>
---
### Exercise: Convert different text formats into timestamps

```sql
SELECT '2017-01-01 00:00-6'::timestamptz;

SELECT '2017-01-01'::timestamptz;

SELECT '4/5/2017'::timestamptz;
```
---

Day/month/year and month/day/year can be particularly problematic as they are each preferred in different parts of the world.


### Exercise: Use session settings to control Timestamp in/out

```sql
SET datestyle to dmy;
SELECT '4/5/2017'::timestamptz;

SET datestyle TO DEFAULT;
SELECT '4/5/2017'::timestamptz;
```
---

By using the TimestampTZ data type it becomes easy to view the data in whatever locality is necessary at the moment.


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

SELECT now() AT TIME ZONE 'America/Chicago';
```
---

PostgreSQL also has an interval type that can maintain periods of time


```sql
SELECT '1 day'::interval;
SELECT '2016-01-01'::timestamptz + '3 months'::interval;
```
---

When no proper Time Data Types are available, one convenient way of dealing with time is to use Unix Epoch time. This is the number of seconds since the start of the Unix Epoch (1979-01-01). We will see later that using Unix Epoch can be very handy when we start to look at PostGIS Linear Referencing.


## Exercise: Convert between Time Data Types and Epoch Seconds

```sql
SELECT to_timestamp(0);

SELECT timezone('UTC',to_timestamp(0));

SELECT extract(epoch from '2017-01-01'::timestamptz);

SELECT extract(epoch from '1 hour'::interval);
```
---

For convenience sake if you are doing this conversion frequently, PostgreSQL makes creating your own functions very easy. Let's create custom functions for converting Intervals and TimestampTZ into Epochs.


## Exercise: Create custom functions for converting to Unix Epoch

```sql
CREATE OR REPLACE FUNCTION to_epoch(IN timestamptz, OUT float8) AS $$
    SELECT extract(epoch from $1);
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION to_epoch(IN interval, OUT float8) AS $$
    SELECT extract(epoch from $1);
$$ LANGUAGE SQL;

SELECT to_epoch('2017-01-01'::timestamptz);
SELECT to_epoch('1 hour'::interval);
```
---

It can be very convenient to also be able to "round" time.


## Exercise: Truncate timestamps.
```sql
SELECT date_trunc('month', now());
SELECT date_trunc('month', now()) + '1 month'::interval;
```

---
## Exercise: Load Superior 100 Race Course
```bash
shp2pgsql -I -s 26915 -D -t 2D superior100.shp superior100 | psql superior
```
```sql
SELECT id, substring(st_asewkt(geom),0,100) FROM superior100;
```
---
Let's take a look at this track by blowing it up into the component points. [ST_DumpPoints](https://postgis.net/docs/ST_DumpPoints.html) is a Set Returning Function that returns a record data type. In order to access the columns in the record, you'll notice that we must wrap the column that contains the record in parentheses.

## Exercise: Show first 10 points of track
```sql
SELECT st_dumppoints(geom) FROM superior100 limit 10;
SELECT (st_dumppoints(geom)).* FROM superior100 limit 10;
```
---
## Exercise: Now let's do that in a more useful way
```sql
WITH t AS (SELECT st_dumppoints(geom) as dump FROM superior100)
SELECT 
    (dump).path[2],
    st_asewkt((dump).geom), 
    st_x((dump).geom), 
    st_y((dump).geom)
FROM t 
LIMIT 10;
```
---
## Exercise Create a table with all the points from the track
```sql
CREATE TABLE superior100_points AS 
WITH t AS (SELECT st_dumppoints(geom) as dump FROM superior100)
SELECT 
    (dump).path[2],
    (dump).geom, 
    st_x((dump).geom) as x, 
    st_y((dump).geom) as y
FROM t;
```
---
## Exercise Add an elevation to our table of track points
Load a dem into PostGIS Raster
```bash
raster2pgsql -I -Y -C -s 26915 -t 100x100 sht_dem25m.tif dem | psql superior
```
Use [st_value](https://postgis.net/docs/RT_ST_Value.html) to assign the elevation for each point.
```sql
ALTER TABLE superior100_points ADD COLUMN z float8;

UPDATE superior100_points 
SET 
    z=st_value(rast,geom)
FROM dem 
WHERE st_intersects(dem.rast,geom);
```
---

In that exercise we just add the value to a z column, now we need to actually add that to the point. We can do that using the [st_makepoint](https://postgis.net/docs/ST_MakePoint.html) function. Note that this function returns a point without projection information which we need to add using [st_setsrid](https://postgis.net/docs/ST_SetSRID.html).

## Exercise: Add this new dimension to our point geometries
```sql
SELECT st_asewkt(geom), x, y, z FROM superior100_points LIMIT 10;

UPDATE superior100_points 
SET geom = st_setsrid(st_makepoint(x,y,z), 26915);

SELECT st_asewkt(geom) FROM superior100_points LIMIT 10;
```
---

Now that we have added the third dimension to our points, we want to be able to convert that back into a line.
We can do that using the [st_makeline](https://postgis.net/docs/ST_MakeLine.html) function which can act as an aggregate for a set of points.

## Exercise: Reassemble points into a line.
```sql
WITH t AS (SELECT * FROM superior100_points ORDER BY PATH)
SELECT substring(st_asewkt(st_makeline(geom)),1,100) FROM t;
```
---
## Exercise: Let's save the 3d line into a new table
```sql
CREATE TABLE superior1003d AS
WITH t AS (SELECT * FROM superior100_points ORDER BY PATH)
SELECT st_makeline(geom) as geom FROM t;
```
---

Now that we have our data as a set of ordered points, using [Window Functions](https://www.postgresql.org/docs/9.6/static/tutorial-window.html) we can start to have fun and extract useful information about what is happening along our track. In trail running, it is very useful to understand what the terrain is like by understanding what the elevation gain and loss is. We'll use the elevation data that we created to figure out how much climbing and descending there is along this trail.

## Exercise: Look at the elevation change between each segment
```sql
SELECT path, x, y, z, z-lag(z) OVER (ORDER BY PATH) 
FROM superior100_points LIMIT 20;
```
---
## Exercise: Add this elevation change to our table
```sql
ALTER TABLE superior100_points ADD COLUMN elchange float8;

WITH t AS (SELECT path, x, y, z, 
    round((z-lag(z) OVER (ORDER BY PATH))::numeric,1) elchange 
    FROM superior100_points)
UPDATE superior100_points p SET elchange=t.elchange 
FROM t WHERE p.path=t.path;

SELECT x, y, z, elchange FROM superior100_points limit 10;
```
---

Now that we have the change per segment we can see how much total climbing and descending there is.

## Exercise: Calculate overall elevation change
```sql
SELECT 
    3.28 * sum(elchange) FILTER (WHERE elchange>0) as gain, 
    3.28 * sum(elchange) FILTER (WHERE elchange<0) as descent 
FROM superior100_points;
```
---

We can also do interesting things like calculate the direction between points using [st_azimuth](http://www.postgis.org/docs/ST_Azimuth.html). This can be especially useful if you are trying to create animations that show things like a plane icon pointing in the right direction. Note this function returns the direction in radians that we have to convert to degrees.

## Exercise: Calculate the direction of each segment
```sql
SELECT path, x, y, z, 
    degrees(st_azimuth(lag(geom) OVER (ORDER BY path), geom)) 
FROM superior100_points LIMIT 20;
```
---

PostGIS has the ability to calculate lengths and distances taking into account our third dimension, let's take a look at the differences between a 2d length calculation and one that takes into account the elevation changes using the explicit [st_3dlength](https://postgis.net/docs/ST_3DLength.html).

## Exercise: Compare 2d and 3d length
```sql
SELECT st_length(geom)/1609 FROM superior1003d;
SELECT st_3dlength(geom)/1609 FROM superior1003d;
```
---
# [Linear Referencing](https://postgis.net/docs/reference.html#Linear_Referencing)

PostGIS comes with a great set of tools for doing interpolation along tracks. These tools either use the ration along the track (from 0-1) or they use a 4th ordinate as a measure, referred to as the M ordinate.

---
## Exercise: Use [st_lineinterpolatepoint](https://postgis.net/docs/ST_LineInterpolatePoint.html) to calculate the halfway point and the point 50 miles along our track.

These will both be using just the 2d distance.


```sql
SELECT st_asewkt(st_lineinterpolatepoint(geom,.5)) 
FROM superior1003d;

SELECT st_asewkt(st_lineinterpolatepoint(geom,50*1609/st_length(geom)))
FROM superior1003d;
```
---

Geographic data collection is not always entirely precise (shocker). The official distance for this race is 103.2 miles and all the aid stations have mileages given to them that do not entirely match the track that we have. For planning purposes and to match all the signage on the course, it is more important for us to match with those published distances than with the distances that we have along our track. Let's take a look at what those differences mean for our course. We can use [st_linelocatepoint](https://postgis.net/docs/ST_LineLocatePoint.html) to find the point on the track nearest a given point (in this case our aid station).

---
## Exercise: Load aid station locations
```bash
shp2pgsql -s 26915 -D -I aidstations.shp aidstations | psql superior
```
---
## Exercise: Look at aid station locations as ratios along the track by using both the mileage along as a ratio of total distance and by the aid station location
```sql
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
```
---

Using the aid stations, we can separate our track into sections that we know what the distance should be between each section. We'll use our window functions again to calculate the distance between each aid station and to locate the aidstations as ratios along our track. We can then extract each section using another linear referencing function [st_linesubstring](https://postgis.net/docs/ST_LineSubstring.html) which works very similar to a string substring function splitting out the section of the track using these ratios.

## Exercise: Split track into segments between aid stations
```sql
CREATE TABLE sections AS
SELECT 
    aidstation,
    miles,
    st_addmeasure(
        st_linesubstring(
            s.geom,
            st_linelocatepoint(s.geom,
                lag(a.geom) OVER (ORDER BY miles)),
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
```
---

Now that we have measures calculated per section, we can recombine those sections to create a single track with our corrected distance measures along the entire track.

## Exercise: Merge the line segments together
```sql
CREATE TABLE superior1003dm AS 
SELECT st_linemerge(st_collect(geom)) AS geom FROM sections;

SELECT substring(st_asewkt(geom),0,100) FROM superior1003dm;
```

UH OH! Notice that in this result, our measure value (the 4th ordinate) is missing! Not all functions in PostGIS maintain the 4th dimension!

---

We're not done yet, remember we can still blow our tracks into individual points and sew them back together

## Exercise: Merge the line segments together take 2
```sql
DROP TABLE superior1003dm;
CREATE TABLE superior1003dm AS 
WITH 
p1 AS 
    (SELECT (st_dumppoints(geom)).* FROM sections),
p2 AS
    (SELECT DISTINCT ON (st_m(geom)) geom, st_m(geom) 
     FROM p1 ORDER BY st_m(geom))
SELECT st_makeline(geom) as geom FROM p2;

SELECT substring(st_asewkt(geom),0,100) FROM superior1003dm;
```

Why did we have to use the "DISTINCT ON"? For each segment when we constructed the segment the endpoint of on is the startpoint of the next and we don't want to double those points

---

We've now learned how to use our M ordinate to store information about distance information, but we all came here to learn how we can work with time and PostGIS. I've found the last three years splits for the race for each aid station. We can use this data to start to develop a pace chart for where I can hope to run. Let's load this split data (to save time we are just going to use a sql script to load and format the data for us to use)

```bash
psql -a -f loadresults.sql superior
```
---
## Exercise: Explore our splits data
```sql
SELECT * FROM superiorsplits ORDER BY runnerid, aidstation LIMIT 20;

SELECT aidstation, min(split), avg(split), max(split) 
FROM superiorsplits GROUP BY aidstation ORDER BY min(split);
```
---

I'm slow.
Probably not best to try to calculate my splits from all the results, let's limit it to folks who finished in the time range that I hope to finish in.

## Exercise: Find average times to get to each aid station to finish in around 36 hours
```sql
SELECT aidstation, min(split), avg(split), max(split) 
FROM superiorsplits 
WHERE finish BETWEEN '35 hours'::interval AND '37 hours'::interval
GROUP BY aidstation ORDER BY min(split);
```
---

Once we have the splits we can create a pace chart for when I should get to each aid station.

## Exercise: Create pace chart for a 36 hour goal
```sql
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
    goal - 
        coalesce(lag(goal) OVER (ORDER BY miles),'0 hours'::interval) 
        AS goal_section,
    '2017-09-08 08:00:00 CDT'::timestamptz + goal AS goal_time,
    (goal - coalesce(lag(goal) OVER (ORDER BY miles),'0 hours'::interval)) 
    /  
    (miles - coalesce(lag(miles) OVER (ORDER BY miles),0))
    as pace_section
FROM
    sections JOIN goalsplits USING (aidstation)
;
```
---
## Exercise: Take a gander at our pace chart
```sql
SELECT * FROM bitner_goal;
```
---

Now that we know what time we want to get to each aid station, we can also create a track similar to what we did for our distance measure along only using time for our measure rather than distance. Now we can't use an interval or timestamptz as our M value, so instead we are going to use the Unix Epoch or a number of seconds. We can use either the actual timestamptz or we can use time along the course. We're going to use the latter.

## Exercise: Create a track that contains our time along measure for our goals
```sql
CREATE TABLE bitner_goal_track AS
WITH
t1 AS (
    SELECT 
        st_addmeasure(geom, to_epoch(goal_from), to_epoch(goal_to)) 
            AS geom
    FROM
        sections JOIN bitner_goal USING (aidstation)
),
p1 AS 
    (SELECT (st_dumppoints(geom)).* FROM t1),
p2 AS
    (SELECT DISTINCT ON (st_m(geom)) geom, st_m(geom) 
     FROM p1 ORDER BY st_m(geom))
SELECT st_makeline(geom) as geom FROM p2;

SELECT substring(st_asewkt(geom),0,100) FROM bitner_goal_track;
```
---

I have a satellite tracker that I carry with on these races that every ten minutes let's my crew (the people who meet me at the aid stations to help me out) know where I am. Now I can pass in a point from that tracker anywher along the track and my crew can tell how far ahead or behind of my planned pace I am. Similarly for any given point or distance along the track they could tell when I am hoping to get there (if you are moving through these exercises really fast you can take that on as a challenge exercise).

## Exercise: Find where I should be at given a location
```sql
WITH point AS 
(SELECT st_geometryn(st_locatealong(geom,60),1) as point FROM superior1003dm)
SELECT 
        (st_m(
            st_lineinterpolatepoint(
                geom,
                st_linelocatepoint(geom,point.point)
            )
        )::text || ' seconds')::interval
FROM bitner_goal_track, point;
```
---

We can to the same as we've done with my target times to create tracks from the previous runners

```sql
SELECT * FROM superiorsplits 
WHERE aidstation='finish' AND finish BETWEEN '35.5 hours'::interval AND '36.5 hours'::interval LIMIT 20;
```
---
# Challenge: Try to create a track using the split times for a previous finisher running near 36 hours and create a time measured track. Try not to cheat and use the solution below!!!
```sql
CREATE TABLE target_goal AS 
WITH 
goalsplits AS (
    SELECT aidstation, split as goal
    FROM superiorsplits 
    WHERE runnerid = 93
)
SELECT 
    aidstation,
    miles AS miles,
    miles - coalesce(lag(miles) OVER (ORDER BY miles),0) 
        AS miles_section,
    coalesce(lag(goal) OVER (ORDER BY miles),'0 hours'::interval) 
        AS goal_from,
    goal AS goal_to,
    goal - 
        coalesce(lag(goal) OVER (ORDER BY miles),'0 hours'::interval) 
        AS goal_section,
    '2017-09-08 08:00:00 CDT'::timestamptz + goal AS goal_time,
    (goal - coalesce(lag(goal) OVER (ORDER BY miles),'0 hours'::interval)) 
    /  
    (miles - coalesce(lag(miles) OVER (ORDER BY miles),0))
    as pace_section
FROM
    sections JOIN goalsplits USING (aidstation)
;

SELECT * FROM target_goal;
```
---
```sql
CREATE TABLE target_goal_track AS
WITH
t1 AS (
    SELECT 
        st_addmeasure(geom, to_epoch(goal_from), 
        to_epoch(goal_to)) AS geom
    FROM
        sections JOIN target_goal USING (aidstation)
),
p1 AS 
    (SELECT (st_dumppoints(geom)).* FROM t1),
p2 AS
    (SELECT DISTINCT ON (st_m(geom)) geom, st_m(geom) 
     FROM p1 ORDER BY st_m(geom))
SELECT st_makeline(geom) as geom FROM p2;

SELECT substring(st_asewkt(geom),0,100) FROM target_goal_track;
```
---

When we are adding an M value, PostGIS will allow us to add any value that we want. In order to be a "proper measure" those values should be continuously increasing along the path. PostGIS has a function [st_isvalidtrajectory](https://postgis.net/docs/ST_IsValidTrajectory.html) that will check for this.

## Exercise: Check our two tracks for good measures
```sql
SELECT st_isvalidtrajectory(geom) FROM bitner_goal_track;
SELECT st_isvalidtrajectory(geom) FROM target_goal_track;
```
---

Once we have valid trajectories, we can use the closest point of approach functions [st_closestpointofapproach](https://postgis.net/docs/ST_ClosestPointOfApproach.html) and [st_distancecpa](https://postgis.net/docs/ST_DistanceCPA.html) to find out if two trajectories met and when (or the closest they got). We'll just look at the last half of the tracks as everyone was together at the start.

## Exercise: Determine how close my goal track and the track created from a previous runner got
```sql
SELECT (st_closestpointofapproach(
    (SELECT st_linesubstring(geom,.5,1) FROM bitner_goal_track),
    (SELECT st_linesubstring(geom,.5,1) FROM target_goal_track)
)::text || ' seconds')::interval;

SELECT st_distancecpa(
    (SELECT st_linesubstring(geom,.5,1) FROM bitner_goal_track),
    (SELECT st_linesubstring(geom,.5,1) FROM target_goal_track)
);
```
---
## Bonus Exercises #1
Using previous race times, if I get to an aid station at a given time, use the other finishers who got to that aid station near that time to predict when I will get to all the following aid stations with some indicator of margin or error.
---

## Bonus Exercise #2
Using previous race times, given a location/time that I am at any point in the race, predict when I will get to the following aid stations.
