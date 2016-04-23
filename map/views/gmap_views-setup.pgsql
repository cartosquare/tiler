
-- Setup
--
--     psql -U username -f gmap_views-setup.pgsql databasename
--
-- Removal, upgrading
--
--     psql -U username -f gmap_views-remove.pgsql databasename

BEGIN;

DROP VIEW IF EXISTS roads;
DROP VIEW IF EXISTS tunnels;
DROP VIEW IF EXISTS minor_roads_casing;
DROP VIEW IF EXISTS minor_roads_fill;
DROP VIEW IF EXISTS turning_circle;
DROP VIEW IF EXISTS footbikecycle_tunnels;
DROP VIEW IF EXISTS tracks_tunnels;
DROP VIEW IF EXISTS line_features;
DROP VIEW IF EXISTS polygon_barriers;
DROP VIEW IF EXISTS highway_area_casing;
DROP VIEW IF EXISTS highway_area_fill;
DROP VIEW IF EXISTS tracks_notunnel_nobridge;
DROP VIEW IF EXISTS access_pre_bridges;
DROP VIEW IF EXISTS direction_pre_bridges;
DROP VIEW IF EXISTS landcover;
DROP VIEW IF EXISTS landcover_line;
DROP VIEW IF EXISTS sports_grounds;
DROP VIEW IF EXISTS ferry_routes;
DROP VIEW IF EXISTS aerialways;
DROP VIEW IF EXISTS buildings_lz;
DROP VIEW IF EXISTS buildings;
DROP VIEW IF EXISTS water_lines_casing;
DROP VIEW IF EXISTS water_areas;
DROP VIEW IF EXISTS water_areas_overlay;
DROP VIEW IF EXISTS glaciers_text;
DROP VIEW IF EXISTS water_lines_low_zoom;
DROP VIEW IF EXISTS water_lines;
DROP VIEW IF EXISTS dam;
DROP VIEW IF EXISTS marinas_area;
DROP VIEW IF EXISTS piers_area;
DROP VIEW IF EXISTS piers;
DROP VIEW IF EXISTS locks;
DROP VIEW IF EXISTS bridges_layer1;
DROP VIEW IF EXISTS bridges_access1;
DROP VIEW IF EXISTS bridges_directions1;
DROP VIEW IF EXISTS bridges_layer2;
DROP VIEW IF EXISTS bridges_access2;
DROP VIEW IF EXISTS bridges_directions2;
DROP VIEW IF EXISTS bridges_layer3;
DROP VIEW IF EXISTS bridges_access3;
DROP VIEW IF EXISTS bridges_directions3;
DROP VIEW IF EXISTS bridges_layer4;
DROP VIEW IF EXISTS bridges_access4;
DROP VIEW IF EXISTS bridges_directions4;
DROP VIEW IF EXISTS bridges_layer5;
DROP VIEW IF EXISTS bridges_access5;
DROP VIEW IF EXISTS bridges_directions5;
DROP VIEW IF EXISTS trams;
DROP VIEW IF EXISTS guideways;
DROP VIEW IF EXISTS admin_01234;
DROP VIEW IF EXISTS admin_5678;
DROP VIEW IF EXISTS admin_other;
DROP VIEW IF EXISTS placenames_large;
DROP VIEW IF EXISTS placenames_capital;
DROP VIEW IF EXISTS placenames_medium;
DROP VIEW IF EXISTS placenames_small;
DROP VIEW IF EXISTS amenity_stations;
DROP VIEW IF EXISTS amenity_stations_poly;
DROP VIEW IF EXISTS amenity_symbols;
DROP VIEW IF EXISTS amenity_symbols_poly;
DROP VIEW IF EXISTS amenity_points;
DROP VIEW IF EXISTS amenity_points_poly;
DROP VIEW IF EXISTS roads_text_name;
DROP VIEW IF EXISTS text;
DROP VIEW IF EXISTS text_poly;
DROP VIEW IF EXISTS area_text;
DROP VIEW IF EXISTS housenumbers;
DROP VIEW IF EXISTS housenames;
DROP VIEW IF EXISTS landuse_overlay;
DROP VIEW IF EXISTS power_line;
DROP VIEW IF EXISTS power_minorline;
DROP VIEW IF EXISTS power_towers;
DROP VIEW IF EXISTS power_poles;
DROP VIEW IF EXISTS interpolation_lines;
DROP VIEW IF EXISTS misc_boundaries;
DROP VIEW IF EXISTS theme_park;

DELETE FROM geometry_columns
WHERE f_table_name
   IN ('roads', 'tunnels', 'minor_roads_casing', 'minor_roads_fill', 'turning_circle', 'footbikecycle_tunnels', 'tracks_tunnels', 'line_features', 'polygon_barriers', 'highway_area_casing', 'highway_area_fill', 'tracks_notunnel_nobridge', 'access_pre_bridges', 'direction_pre_bridges', 'landcover', 'landcover_line', 'sports_grounds', 'ferry_routes', 'aerialways', 'buildings_lz', 'buildings', 'water_lines_casing', 'water_areas', 'water_areas_overlay', 'glaciers_text', 'water_lines_low_zoom', 'water_lines', 'dam', 'marinas_area', 'piers_area', 'piers', 'locks', 'bridges_layer1', 'bridges_access1', 'bridges_directions1', 'bridges_layer2', 'bridges_access2', 'bridges_directions2', 'bridges_layer3', 'bridges_access3', 'bridges_directions3', 'bridges_layer4', 'bridges_access4', 'bridges_directions4', 'bridges_layer5', 'bridges_access5', 'bridges_directions5', 'trams', 'guideways', 'admin_01234', 'admin_5678', 'admin_other', 'placenames_large', 'placenames_capital', 'placenames_medium', 'placenames_small', 'amenity_stations', 'amenity_stations_poly', 'amenity_symbols', 'amenity_symbols_poly', 'amenity_points', 'amenity_points_poly', 'roads_text_name', 'text', 'text_poly', 'area_text', 'landuse_overlay', 'power_line', 'power_minorline', 'power_towers', 'power_poles', 'interpolation_lines', 'misc_boundaries', 'theme_park');

CREATE VIEW roads AS
select way,highway,
     case when tunnel in ('yes','true','1') then 'yes'::text else tunnel end as tunnel,
     case when railway='preserved' and service in ('spur','siding','yard') then 'INT-preserved-ssy'::text else railway end as railway
     from planet_osm_roads
     where highway is not null
        or (railway is not null and railway!='preserved' and (service is null or service not in ('spur','siding','yard')))
        or railway='preserved'
     order by z_order;

CREATE VIEW tunnels AS
select way,highway from planet_osm_line where highway in ('motorway','motorway_link','trunk','trunk_link','primary','primary_link','secondary','secondary_link','tertiary','tertiary_link','residential','unclassified') and tunnel in ('yes','true','1') order by z_order;

CREATE VIEW minor_roads_casing AS
select way,highway,
       case when tunnel in ('yes','true','1') then 'yes'::text else tunnel end as tunnel,
       case when service in ('parking_aisle','drive-through','driveway') then 'INT-minor'::text else service end as service
       from planet_osm_line
       where highway in ('motorway','motorway_link','trunk','trunk_link','primary','primary_link','secondary','secondary_link','tertiary','tertiary_link','residential','unclassified','road','service','pedestrian','raceway','living_street')
       order by z_order;

CREATE VIEW minor_roads_fill AS
select way,highway,horse,bicycle,foot,construction,aeroway,
       case when tunnel in ('yes','true','1') then 'yes'::text else tunnel end as tunnel,
       case when bridge in ('yes','true','1','viaduct','swing','lift') then 'yes'::text else bridge end as bridge,
       case when railway in ('spur','siding')
              or (railway='rail' and service in ('spur','siding','yard'))
            then 'spur-siding-yard'::text else railway end as railway,
       case when service in ('parking_aisle','drive-through','driveway') then 'INT-minor'::text else service end as service
       from planet_osm_line
       where highway is not null
          or aeroway in ('runway','taxiway')
          or railway in ('light_rail','narrow_gauge','funicular','rail','subway','tram','spur','siding','platform','disused','abandoned','construction','miniature','turntable')
       order by z_order;

CREATE VIEW turning_circle AS
select distinct on (p.way) p.way as way,l.highway as int_tc_type
       from planet_osm_point p
       join planet_osm_line l
        on ST_DWithin(p.way,l.way,0.1)
       join (values
        ('tertiary',1),
        ('unclassified',2),
        ('residential',3),
        ('living_street',4),
        ('service',5)
       ) as v (highway,prio)
        on v.highway=l.highway
       where p.highway='turning_circle'
       order by p.way,v.prio;


CREATE VIEW footbikecycle_tunnels AS
select way,highway,horse,foot,bicycle from planet_osm_line where highway in ('bridleway','footway','cycleway','path') and tunnel in ('yes','true','1') order by z_order;

CREATE VIEW tracks_tunnels AS
select way,tracktype from planet_osm_line where highway='track' and tunnel in ('yes','true','1');

CREATE VIEW line_features AS
select way,barrier,"natural",man_made from planet_osm_line where barrier is not null or "natural" in ('hedge','cliff') or man_made='embankment';

CREATE VIEW polygon_barriers AS
select way,barrier,"natural" from planet_osm_polygon where barrier is not null or "natural"='hedge';


CREATE VIEW highway_area_casing AS
select way,highway,railway from planet_osm_polygon
       where highway in ('residential','unclassified','pedestrian','service','footway','track','path','platform')
          or railway='platform'
       order by z_order,way_area desc;

CREATE VIEW highway_area_fill AS
select way,highway,railway,aeroway from planet_osm_polygon
       where highway in ('residential','unclassified','pedestrian','service','footway','living_street','track','path','platform','services')
          or railway='platform'
          or aeroway in ('runway','taxiway','helipad')
       order by z_order,way_area desc;

CREATE VIEW tracks_notunnel_nobridge AS
select way,tracktype from planet_osm_line where highway='track' and (bridge is null or bridge in ('no','false','0')) and (tunnel is null or tunnel in ('no','false','0'));


CREATE VIEW access_pre_bridges AS
select way,access,highway,
       case when service in ('parking_aisle','drive-through','driveway') then 'INT-minor'::text end as service
       from planet_osm_line
       where access is not null and highway is not null
         and (bridge is null or bridge not in ('yes','true','1','viaduct','swing','lift'));


CREATE VIEW direction_pre_bridges AS
select way,
       case when oneway in ('yes','true','1') then 'yes'::text else oneway end as oneway
       from planet_osm_roads
       where oneway is not null
         and (highway is not null or railway is not null or waterway is not null)
         and (bridge is null or bridge not in ('yes','true','1','viaduct','swing','lift'));

CREATE VIEW landcover AS
select way,aeroway,amenity,landuse,leisure,man_made,military,"natural",power,tourism,name,highway,
       case when religion in ('christian','jewish') then religion else 'INT-generic'::text end as religion
       from planet_osm_polygon
       where landuse is not null
          or leisure is not null
          or aeroway in ('apron','aerodrome')
          or amenity in ('parking','university','college','school','hospital','kindergarten','grave_yard','prison')
          or military in ('barracks','danger_area')
          or "natural" in ('field','beach','desert','heath','mud','grassland','wood','sand','scrub')
          or power in ('station','sub_station','generator')
          or tourism in ('attraction','camp_site','caravan_site','picnic_site','zoo')
          or highway in ('services','rest_area')
       order by z_order,way_area desc;


CREATE VIEW landcover_line AS
select way
       from planet_osm_line
       where man_made='cutline';

CREATE VIEW sports_grounds AS
select way,leisure,
       case when leisure='pitch' then 2
            when leisure='track' then 1
            else 0 end as prio
       from planet_osm_polygon
       where leisure in ('sports_centre','stadium','pitch','track')
       order by z_order,prio,way_area desc;

CREATE VIEW ferry_routes AS
select way from planet_osm_line where route='ferry';

CREATE VIEW aerialways AS
select way,aerialway from planet_osm_line where aerialway is not null;

CREATE VIEW buildings AS
select way,aeroway,
        case
         when building in ('residential','house','garage','garages','detached','terrace','apartments') then 'INT-light'::text
         else building
        end as building
       from planet_osm_polygon
       where (building is not null
         and building not in ('no','station','supermarket','planned')
         and (railway is null or railway != 'station')
         and (amenity is null or amenity != 'place_of_worship'))
          or aeroway = 'terminal'
       order by z_order,way_area desc;


CREATE VIEW buildings_lz AS
select way,building,railway,amenity from planet_osm_polygon
       where railway='station'
          or building in ('station','supermarket')
          or amenity='place_of_worship'
       order by z_order,way_area desc;

CREATE VIEW water_lines_casing AS
select way,waterway
      from planet_osm_line
      where waterway in ('stream','drain','ditch')
        and (tunnel is null or tunnel != 'yes');


CREATE VIEW water_areas AS
select way,"natural",waterway,landuse,name
      from planet_osm_polygon
      where (waterway in ('dock','mill_pond','riverbank','canal')
         or landuse in ('reservoir','water','basin')
         or "natural" in ('lake','water','land','glacier','mud','bay'))
         and building is null
      order by z_order,way_area desc;


CREATE VIEW water_areas_overlay AS
select way,"natural"
      from planet_osm_polygon
      where "natural" in ('marsh','wetland') and building is null
      order by z_order,way_area desc;


CREATE VIEW glaciers_text AS
select way,name,way_area
      from planet_osm_polygon
      where "natural"='glacier' and building is null
      order by way_area desc;


CREATE VIEW water_lines_low_zoom AS
select way,waterway
      from planet_osm_line
      where waterway='river';


CREATE VIEW water_lines AS
select way,waterway,disused,lock,name,
      case when tunnel in ('yes','true','1') then 'yes'::text else tunnel end as tunnel
      from planet_osm_line
      where waterway in ('weir','river','canal','derelict_canal','stream','drain','ditch','wadi')
        and (bridge is null or bridge not in ('yes','true','1','aqueduct'))
      order by z_order;

CREATE VIEW dam AS
select way,name from planet_osm_line where waterway='dam';


CREATE VIEW marinas_area AS
select way from planet_osm_polygon where leisure ='marina';


CREATE VIEW piers_area AS
select way,man_made from planet_osm_polygon where man_made in ('pier','breakwater','groyne');


CREATE VIEW piers AS
select way,man_made from planet_osm_line where man_made in ('pier','breakwater','groyne');

CREATE VIEW locks AS
select way,waterway from planet_osm_point where waterway='lock_gate';


CREATE VIEW bridges_layer1 AS 
select way,highway,aeroway,horse,bicycle,foot,tracktype,
       case when railway in ('spur','siding')
              or (railway='rail' and service in ('spur','siding','yard'))
            then 'INT-spur-siding-yard'::text else railway end as railway
       from planet_osm_line
       where (highway is not null
              or aeroway in ('runway','taxiway')
              or railway in ('light_rail','subway','narrow_gauge','rail','spur','siding','disused','abandoned','construction'))
         and bridge in ('yes','true','1','viaduct','swing','lift')
         and layer = '1'
       order by z_order;
         
CREATE VIEW bridges_access1 AS 
select way,access,highway,
       case when service in ('parking_aisle','drive-through','driveway') then 'INT-minor'::text end as service
       from planet_osm_line
       where access is not null and highway is not null
         and bridge in ('yes','true','1','viaduct','swing','lift')
         and layer = '1';
         
CREATE VIEW bridges_directions1 AS 
select way,
       case when oneway in ('yes','true','1') then 'yes'::text else oneway end as oneway
       from planet_osm_line
       where oneway is not null
         and (highway is not null or railway is not null or waterway is not null)
         and bridge in ('yes','true','1','viaduct','swing','lift')
         and layer = '1';
         
         
CREATE VIEW bridges_layer2 AS 
select way,highway,aeroway,horse,bicycle,foot,tracktype,
       case when railway in ('spur','siding')
              or (railway='rail' and service in ('spur','siding','yard'))
            then 'INT-spur-siding-yard'::text else railway end as railway
       from planet_osm_line
       where (highway is not null
              or aeroway in ('runway','taxiway')
              or railway in ('light_rail','subway','narrow_gauge','rail','spur','siding','disused','abandoned','construction'))
         and bridge in ('yes','true','1','viaduct','swing','lift')
         and layer = '2'
       order by z_order;
       
CREATE VIEW bridges_access2 AS 
select way,access,highway,
       case when service in ('parking_aisle','drive-through','driveway') then 'INT-minor'::text end as service
       from planet_osm_line
       where access is not null and highway is not null
         and bridge in ('yes','true','1','viaduct','swing','lift')
         and layer = '2';
         
CREATE VIEW bridges_directions2 AS 
select way,
       case when oneway in ('yes','true','1') then 'yes'::text else oneway end as oneway
       from planet_osm_line
       where oneway is not null
         and (highway is not null or railway is not null or waterway is not null)
         and bridge in ('yes','true','1','viaduct','swing','lift')
         and layer = '2';
         
CREATE VIEW bridges_layer3 AS 
select way,highway,aeroway,horse,bicycle,foot,tracktype,
       case when railway in ('spur','siding')
              or (railway='rail' and service in ('spur','siding','yard'))
            then 'INT-spur-siding-yard'::text else railway end as railway
       from planet_osm_line
       where (highway is not null
              or aeroway in ('runway','taxiway')
              or railway in ('light_rail','subway','narrow_gauge','rail','spur','siding','disused','abandoned','construction'))
         and bridge in ('yes','true','1','viaduct','swing','lift')
         and layer = '3'
       order by z_order;
       
CREATE VIEW bridges_access3 AS 
select way,access,highway,
       case when service in ('parking_aisle','drive-through','driveway') then 'INT-minor'::text end as service
       from planet_osm_line
       where access is not null and highway is not null
         and bridge in ('yes','true','1','viaduct','swing','lift')
         and layer = '3';
         
CREATE VIEW bridges_directions3 AS 
select way,
       case when oneway in ('yes','true','1') then 'yes'::text else oneway end as oneway
       from planet_osm_line
       where oneway is not null
         and (highway is not null or railway is not null or waterway is not null)
         and bridge in ('yes','true','1','viaduct','swing','lift')
         and layer = '3';
         
CREATE VIEW bridges_layer4 AS 
select way,highway,aeroway,horse,bicycle,foot,tracktype,
       case when railway in ('spur','siding')
              or (railway='rail' and service in ('spur','siding','yard'))
            then 'INT-spur-siding-yard'::text else railway end as railway
       from planet_osm_line
       where (highway is not null
              or aeroway in ('runway','taxiway')
              or railway in ('light_rail','subway','narrow_gauge','rail','spur','siding','disused','abandoned','construction'))
         and bridge in ('yes','true','1','viaduct','swing','lift')
         and layer = '4'
       order by z_order;
       
CREATE VIEW bridges_access4 AS 
select way,access,highway,
       case when service in ('parking_aisle','drive-through','driveway') then 'INT-minor'::text end as service
       from planet_osm_line
       where access is not null and highway is not null
         and bridge in ('yes','true','1','viaduct','swing','lift')
         and layer = '4';
         
CREATE VIEW bridges_directions4 AS 
select way,
       case when oneway in ('yes','true','1') then 'yes'::text else oneway end as oneway
       from planet_osm_line
       where oneway is not null
         and (highway is not null or railway is not null or waterway is not null)
         and bridge in ('yes','true','1','viaduct','swing','lift')
         and layer = '4';
         
CREATE VIEW bridges_layer5 AS 
select way,highway,aeroway,horse,bicycle,foot,tracktype,
       case when railway in ('spur','siding')
              or (railway='rail' and service in ('spur','siding','yard'))
            then 'INT-spur-siding-yard'::text else railway end as railway
       from planet_osm_line
       where (highway is not null
              or aeroway in ('runway','taxiway')
              or railway in ('light_rail','subway','narrow_gauge','rail','spur','siding','disused','abandoned','construction'))
         and bridge in ('yes','true','1','viaduct','swing','lift')
         and layer = '5'
       order by z_order;
       
CREATE VIEW bridges_access5 AS 
select way,access,highway,
       case when service in ('parking_aisle','drive-through','driveway') then 'INT-minor'::text end as service
       from planet_osm_line
       where access is not null and highway is not null
         and bridge in ('yes','true','1','viaduct','swing','lift')
         and layer = '5';
         
CREATE VIEW bridges_directions5 AS 
select way,
       case when oneway in ('yes','true','1') then 'yes'::text else oneway end as oneway
       from planet_osm_line
       where oneway is not null
         and (highway is not null or railway is not null or waterway is not null)
         and bridge in ('yes','true','1','viaduct','swing','lift')
         and layer = '5';

CREATE VIEW trams AS
select way,railway,bridge from planet_osm_line where railway='tram' and (tunnel is null or tunnel not in ('yes','true','1'));


CREATE VIEW guideways AS
select way from planet_osm_line where highway='bus_guideway' and (tunnel is null or tunnel not in ('yes','true','1'));

CREATE VIEW admin_01234 AS
select way,admin_level
       from planet_osm_roads
       where "boundary"='administrative'
         and admin_level in ('0','1','2','3','4');

CREATE VIEW admin_5678 AS
select way,admin_level
       from planet_osm_roads
       where "boundary"='administrative'
         and admin_level in ('5','6','7','8');
         
CREATE VIEW admin_other AS
select way,admin_level
       from planet_osm_roads
       where "boundary"='administrative'
         and (admin_level is null or admin_level not in ('0','1','2','3','4','5','6','7','8'));

CREATE VIEW placenames_large AS
select way,
       case when name = '中華民國' then 'state'::text else place end as place,
       case when name = '中華民國' then '台湾'::text else name end as name,
       ref
       from planet_osm_point
       where place in ('country','state');
       
CREATE VIEW placenames_capital AS
select way,place,name,ref
       from planet_osm_point
       where place in ('city','metropolis','town') and capital='yes' and name != '臺北市';
       
CREATE VIEW placenames_medium AS
select way,place,name
      from planet_osm_point
      where place in ('city','metropolis','town','large_town','small_town')
        and (capital is null or capital != 'yes' or name = '臺北市');
        
CREATE VIEW placenames_small AS
select way,place,name
      from planet_osm_point
      where place in ('suburb','village','large_village','hamlet','locality','isolated_dwelling','farm');

CREATE VIEW amenity_stations AS
select way,name,railway,aerialway,disused
      from planet_osm_point
      where railway in ('station','halt','tram_stop','subway_entrance')
         or aerialway='station';
         
CREATE VIEW amenity_stations_poly AS
select way,name,railway,aerialway,disused
      from planet_osm_polygon
      where railway in ('station','halt','tram_stop')
         or aerialway='station';

CREATE VIEW amenity_symbols AS
select *
      from planet_osm_point
      where aeroway in ('airport','aerodrome','helipad')
         or barrier in ('bollard','gate','lift_gate','block')
         or highway in ('mini_roundabout','gate')
         or man_made in ('lighthouse','power_wind','windmill','mast')
         or (power='generator' and ("generator:source"='wind' or power_source='wind'))
         or "natural" in ('peak','volcano','spring','tree','cave_entrance')
         or railway='level_crossing';
         
CREATE VIEW amenity_symbols_poly AS
select *
      from planet_osm_polygon
      where aeroway in ('airport','aerodrome','helipad')
         or barrier in ('bollard','gate','lift_gate','block')
         or highway in ('mini_roundabout','gate')
         or man_made in ('lighthouse','power_wind','windmill','mast')
         or (power='generator' and ("generator:source"='wind' or power_source='wind'))
         or "natural" in ('peak','volcano','spring','tree')
         or railway='level_crossing';
         
CREATE VIEW amenity_points AS
select way,amenity,shop,tourism,highway,man_made,access,religion,waterway,lock,historic,leisure
      from planet_osm_point
      where amenity is not null
         or shop is not null
         or tourism in ('alpine_hut','camp_site','caravan_site','guest_house','hostel','hotel','motel','museum','viewpoint','bed_and_breakfast','information','chalet')
         or highway in ('bus_stop','traffic_signals','ford')
         or man_made in ('mast','water_tower')
         or historic in ('memorial','archaeological_site')
         or waterway='lock'
         or lock='yes'
         or leisure in ('playground','slipway');
         
CREATE VIEW amenity_points_poly AS
select way,amenity,shop,tourism,highway,man_made,access,religion,waterway,lock,historic,leisure
      from planet_osm_polygon
      where amenity is not null
         or shop is not null
         or tourism in ('alpine_hut','camp_site','caravan_site','guest_house','hostel','hotel','motel','museum','viewpoint','bed_and_breakfast','information','chalet')
         or highway in ('bus_stop','traffic_signals')
         or man_made in ('mast','water_tower')
         or historic in ('memorial','archaeological_site')
         or leisure='playground';

CREATE VIEW roads_text_name AS
select way,highway,name
       from planet_osm_line
       where waterway IS NULL
         and leisure IS NULL
         and landuse IS NULL
         and name is not null;
         
CREATE VIEW text AS
select way,amenity,shop,access,leisure,landuse,man_made,"natural",place,tourism,ele,name,ref,military,aeroway,waterway,historic,'yes'::text as point
       from planet_osm_point
       where amenity is not null
          or shop in ('supermarket','bakery','clothes','fashion','convenience','doityourself','hairdresser','department_store','butcher','car','car_repair','bicycle','florist')
          or leisure is not null
          or landuse is not null
          or tourism is not null
          or "natural" is not null
          or man_made in ('lighthouse','windmill')
          or place='island'
          or military='danger_area'
          or aeroway='gate'
          or waterway='lock'
          or historic in ('memorial','archaeological_site');
          
CREATE VIEW text_poly AS
select way,aeroway,shop,access,amenity,leisure,landuse,man_made,"natural",place,tourism,NULL as ele,name,ref,military,waterway,historic,'no'::text as point
       from planet_osm_polygon
       where amenity is not null
          or shop in ('supermarket','bakery','clothes','fashion','convenience','doityourself','hairdresser','department_store', 'butcher','car','car_repair','bicycle')
          or leisure is not null
          or landuse is not null
          or tourism is not null
          or "natural" is not null
          or man_made in ('lighthouse','windmill')
          or place='island'
          or military='danger_area'
          or historic in ('memorial','archaeological_site');
          
CREATE VIEW area_text AS
select way,way_area,name
       from planet_osm_polygon
       where name is not null
         and (waterway is null or waterway != 'riverbank')
         and place is null
         and boundary != 'administrative'
       order by way_area desc;

CREATE VIEW housenumbers AS
select way,"addr:housenumber" from planet_osm_polygon where "addr:housenumber" is not null and building is not null
       union
       select way,"addr:housenumber" from planet_osm_point where "addr:housenumber" is not null;
       
CREATE VIEW housenames AS
select way,"addr:housename" from planet_osm_polygon where "addr:housename" is not null and building is not null
       union
       select way,"addr:housename" from planet_osm_point where "addr:housename" is not null;

CREATE VIEW landuse_overlay AS
select way,landuse,leisure
       from planet_osm_polygon
       where (landuse = 'military' or leisure='nature_reserve') and building is null;

CREATE VIEW power_line AS
select way from planet_osm_line where "power"='line';

CREATE VIEW power_minorline AS
select way from planet_osm_line where "power"='minor_line';

CREATE VIEW power_towers AS
select way from planet_osm_point where power='tower';

CREATE VIEW power_poles AS
select way from planet_osm_point where power='pole';

CREATE VIEW interpolation_lines AS
select way from planet_osm_line where "addr:interpolation" is not null;

CREATE VIEW misc_boundaries AS
select way,way_area,name,boundary from planet_osm_polygon where boundary='national_park' and building is null;

CREATE VIEW theme_park AS
select way,name,tourism from planet_osm_polygon where tourism='theme_park';

INSERT INTO geometry_columns
  (f_table_catalog, f_table_schema, f_table_name, f_geometry_column, coord_dimension, srid, "type")
VALUES
  ('', 'public', 'roads', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'tunnels', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'minor_roads_casing', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'minor_roads_fill', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'turning_circle', 'way', 2, 900913, 'POINT'),
  ('', 'public', 'footbikecycle_tunnels', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'tracks_tunnels', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'line_features', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'polygon_barriers', 'way', 2, 900913, 'GEOMETRY'),
  ('', 'public', 'highway_area_casing', 'way', 2, 900913, 'GEOMETRY'),
  ('', 'public', 'highway_area_fill', 'way', 2, 900913, 'GEOMETRY'),
  ('', 'public', 'access_pre_bridges', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'direction_pre_bridges', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'tracks_notunnel_nobridge', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'landcover', 'way', 2, 900913, 'GEOMETRY'),
  ('', 'public', 'landcover_line', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'ferry_routes', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'aerialways', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'sports_grounds', 'way', 2, 900913, 'GEOMETRY'),
  ('', 'public', 'buildings_lz', 'way', 2, 900913, 'GEOMETRY'),
  ('', 'public', 'buildings', 'way', 2, 900913, 'GEOMETRY'),
  ('', 'public', 'water_lines_casing', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'water_areas', 'way', 2, 900913, 'GEOMETRY'),
  ('', 'public', 'water_areas_overlay', 'way', 2, 900913, 'GEOMETRY'),
  ('', 'public', 'glaciers_text', 'way', 2, 900913, 'GEOMETRY'),
  ('', 'public', 'water_lines_low_zoom', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'water_lines', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'dam', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'marinas_area', 'way', 2, 900913, 'GEOMETRY'),
  ('', 'public', 'piers_area', 'way', 2, 900913, 'GEOMETRY'),
  ('', 'public', 'piers', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'locks', 'way', 2, 900913, 'POINT'),
  ('', 'public', 'bridges_layer1', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'bridges_access1', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'bridges_directions1', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'bridges_layer2', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'bridges_access2', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'bridges_directions2', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'bridges_layer3', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'bridges_access3', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'bridges_directions3', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'bridges_layer4', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'bridges_access4', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'bridges_directions4', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'bridges_layer5', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'bridges_access5', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'bridges_directions5', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'trams', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'guideways', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'admin_01234', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'admin_5678', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'admin_other', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'amenity_stations_poly', 'way', 2, 900913, 'GEOMETRY'),
  ('', 'public', 'amenity_stations', 'way', 2, 900913, 'POINT'),
  ('', 'public', 'amenity_symbols_poly', 'way', 2, 900913, 'GEOMETRY'),
  ('', 'public', 'amenity_symbols', 'way', 2, 900913, 'POINT'),
  ('', 'public', 'amenity_points_poly', 'way', 2, 900913, 'GEOMETRY'),
  ('', 'public', 'amenity_points', 'way', 2, 900913, 'POINT'),
  ('', 'public', 'roads_text_name', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'text', 'way', 2, 900913, 'POINT'),
  ('', 'public', 'text_poly', 'way', 2, 900913, 'GEOMETRY'),
  ('', 'public', 'area_text', 'way', 2, 900913, 'GEOMETRY'),
  ('', 'public', 'housenumbers', 'way', 2, 900913, 'GEOMETRY'),
  ('', 'public', 'housenames', 'way', 2, 900913, 'GEOMETRY'),
  ('', 'public', 'landuse_overlay', 'way', 2, 900913, 'GEOMETRY'),
  ('', 'public', 'power_line', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'power_minorline', 'way', 2, 900913, 'LINESTRING'),
  ('', 'public', 'power_towers', 'way', 2, 900913, 'POINT'),
  ('', 'public', 'power_poles', 'way', 2, 900913, 'POINT'),
  ('', 'public', 'interpolation_lines', 'way', 2, 900913, 'GEOMETRY'),
  ('', 'public', 'misc_boundaries', 'way', 2, 900913, 'GEOMETRY'),
  ('', 'public', 'theme_park', 'way', 2, 900913, 'GEOMETRY');

COMMIT;
