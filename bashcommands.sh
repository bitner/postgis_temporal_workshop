createdb superior
export PGDATABASE=superior
psql -c "CREATE EXTENSION postgis;" superior
psql -c "SELECT postgis_full_version();" superior
shp2pgsql -I -s 26915 -D -t 2D superior100.shp superior100 | psql superior
raster2pgsql -I -Y -C -s 26915 -t 100x100 sht_dem25m.tif dem | psql superior
shp2pgsql -s 26915 -D -I aidstations.shp aidstations | psql superior
psql -a -f loadresults.sql superior
