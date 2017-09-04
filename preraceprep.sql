CREATE OR REPLACE function racertrack (IN runnerid bigint, OUT track geometry) AS $$
WITH 
goalsplits AS (
    SELECT aidstation, split as goal
    FROM superiorsplits 
    WHERE runnerid = $1
),
target_goal AS (
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
),
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
;


$$ LANGUAGE SQL;

DROP TABLE IF EXISTS runners;
DROP TABLE IF EXISTS runnertracks;
create table runners as select runnerid, finish from superiorsplits group by runnerid, finish having count(*)=13;
CREATE TABLE runnertracks as select runnerid, finish, racertrack(runnerid) as geom from runners;

select runnerid, finish, 
    st_asewkt(
        st_lineinterpolatepoint(
            geom,
            st_linelocatepoint(
                geom,
                (select geom from aidstations where aidstation='finland')
            )
        )
    )
FROM runnertracks;