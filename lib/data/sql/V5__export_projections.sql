CREATE TABLE projections_export (id SERIAL, forest_ecoregion TEXT, altitudinal_zone TEXT, forest_type TEXT, additional additional,
                                                                                                            silver_fir_area TEXT, relief relief,
                                                                                                                                  slope TEXT, target_altitudinal_zone TEXT, target_forest_type TEXT);


CREATE OR REPLACE FUNCTION export_projections() RETURNS integer AS $$
DECLARE x integer;
BEGIN
 TRUNCATE projections_export;

INSERT INTO projections_export (forest_ecoregion, altitudinal_zone, forest_type, additional, silver_fir_area, relief, slope, target_altitudinal_zone, target_forest_type) -- 3.) Match CSV values to enum values.
WITH slopes AS
    (SELECT slope,
            array_to_string(regexp_matches(slope, '(<|>).*(\d{2})'), '') parsed_slope
     FROM projections_import)
SELECT DISTINCT processed_forest_ecoregion AS forest_ecoregion,
       altitudinal_zone_meta.code AS altitudinal_zone,
       CASE trim(both from forest_type) = any(SELECT code FROM foresttype_meta)
           WHEN TRUE THEN forest_type
           ELSE null
       END AS forest_type,
       CASE additional_meta.target is null
           WHEN TRUE THEN 'unknown'
           ELSE additional_meta.target
       END AS additional,
       CASE silver_fir_area is null
           WHEN TRUE THEN 'unknown'
           ELSE silver_fir_area_meta.code_ta
       END AS silver_fir_area,
       CASE relief_meta.target is null
           WHEN TRUE THEN 'unknown'
           ELSE relief_meta.target
       END AS relief,
       CASE slopes.slope is null
           WHEN TRUE THEN 'unknown'
           ELSE slopes.parsed_slope
       END AS slope,
       target_altitudinal_zone_meta.code AS target_altitudinal_zone,
       CASE trim(both from target_forest_type) = any(SELECT code FROM foresttype_meta)
           WHEN TRUE THEN target_forest_type
           ELSE null
       END AS target_forest_type
FROM
    (SELECT (regexp_matches(regexp_split_to_table(regexp_replace(regexp_replace(coalesce(forest_ecoregions,forest_ecoregions_specific), '2(,|\s)', '2a, 2b,'), 'R 5', '5a, 5b,'),',\s?'),
                                (SELECT string_agg(subcode, '|'::text)
                                 FROM forest_ecoregions)))[1] AS processed_forest_ecoregion,
            CASE
                   WHEN target_altitudinal_zone ~ 'Nebenareal' THEN 'nebenareal'
                   WHEN target_altitudinal_zone ~ 'Hauptareal' THEN 'hauptareal'
                   WHEN target_altitudinal_zone ~ 'Reliktareal' THEN 'reliktareal'
                   ELSE processed_silver_fir_area
                 END as processed_silver_fir_area2,
                 CASE
                   WHEN target_altitudinal_zone ~ 'hochmontan' THEN 'hochmontan'
                   ELSE target_altitudinal_zone
                 END as processed_target_altitudinal_zone,
            *
     FROM
         (SELECT (regexp_matches(regexp_split_to_table(regexp_replace(regexp_replace(coalesce(trim(lower(silver_fir_area)),'nicht relevant'), 'haupt- und nebenareal', 'hauptareal,nebenareal'),'haupt- oder nebenareal', 'hauptareal,nebenareal'),',\s?') ,
                                     (SELECT string_agg(lower(areal_de)::text, '|'::text) || '|nicht relevant'
                                      FROM silver_fir_areas)))[1] AS processed_silver_fir_area,
                 *
          FROM projections_import) import_silver_fir_area) import
LEFT JOIN altitudinal_zone_meta ON lower(altitudinal_zone_meta.projection::text) = lower(import.altitudinal_zone)
LEFT JOIN altitudinal_zone_meta target_altitudinal_zone_meta ON lower(target_altitudinal_zone_meta.projection::text) = lower(import.processed_target_altitudinal_zone)
LEFT JOIN additional_meta ON lower(additional_meta.source) = lower(import.additional)
LEFT JOIN silver_fir_area_meta ON lower(silver_fir_area_meta.projection) = import.processed_silver_fir_area2
LEFT JOIN relief_meta ON relief_meta.source = import.relief
LEFT JOIN slopes ON slopes.slope = import.slope;

----------------------------------------------
-- export projections_export to json

COPY (
    WITH
          target_altitudinal_zone AS
         (SELECT forest_ecoregion,
                 altitudinal_zone,
                 forest_type,
                 slope,
                 additional,
                 silver_fir_area,
                 relief,
                 jsonb_object_agg(target_altitudinal_zone::text, target_forest_type::text) AS json
          FROM projections_export
          WHERE target_forest_type IS NOT NULL AND target_altitudinal_zone IS NOT NULL
          GROUP BY forest_ecoregion,
                   altitudinal_zone,
                   forest_type,
                   slope,
                   additional,
                   silver_fir_area,
                   relief),
          relief AS
         (SELECT forest_ecoregion,
                 altitudinal_zone,
                 forest_type,
                 slope,
                 additional,
                 silver_fir_area,
                 jsonb_object_agg(relief::text, target_altitudinal_zone.json) AS json
          FROM projections_export
          LEFT JOIN target_altitudinal_zone USING (forest_ecoregion,
                                  altitudinal_zone,
                                  forest_type,
                                  slope,
                                  additional,
                                  silver_fir_area,
                                  relief)
          WHERE target_altitudinal_zone.json IS NOT NULL
          GROUP BY forest_ecoregion,
                   altitudinal_zone,
                   forest_type,
                   slope,
                   additional,
                   silver_fir_area),
          silver_fir_area AS
         (SELECT forest_ecoregion,
                 altitudinal_zone,
                 forest_type,
                 slope,
                 additional,
                 jsonb_object_agg(silver_fir_area::text, relief.json) AS json
          FROM projections_export
          LEFT JOIN relief USING (forest_ecoregion,
                                  altitudinal_zone,
                                  forest_type,
                                  slope,
                                  additional,
                                  silver_fir_area)
          WHERE relief.json IS NOT NULL
          GROUP BY forest_ecoregion,
                   altitudinal_zone,
                   forest_type,
                   slope,
                   additional),
          additional AS
         (SELECT forest_ecoregion,
                 altitudinal_zone,
                 forest_type,
                 slope,
                 jsonb_object_agg(additional::text, silver_fir_area.json) AS json
          FROM projections_export
          LEFT JOIN silver_fir_area USING (forest_ecoregion,
                                           altitudinal_zone,
                                           forest_type,
                                           slope,
                                           additional)
          WHERE silver_fir_area.json IS NOT NULL
          GROUP BY forest_ecoregion,
                   altitudinal_zone,
                   forest_type,
                   slope),
          slope AS
         (SELECT forest_ecoregion,
                 altitudinal_zone,
                 forest_type,
                 jsonb_object_agg(slope::text, additional.json) AS json
          FROM projections_export
          LEFT JOIN additional USING (forest_ecoregion,
                                      altitudinal_zone,
                                      forest_type,
                                      slope)
          WHERE additional.json IS NOT NULL
          GROUP BY forest_ecoregion,
                   altitudinal_zone,
                   forest_type),
          forest_type AS
         (SELECT forest_ecoregion,
                 altitudinal_zone,
                 jsonb_object_agg(forest_type::text, slope.json) AS json
          FROM projections_export
          LEFT JOIN slope USING (forest_ecoregion,
                                 altitudinal_zone,
                                 forest_type)
          WHERE slope.json IS NOT NULL
          GROUP BY forest_ecoregion,
                   altitudinal_zone),
          altitudinal_zone AS
         (SELECT forest_ecoregion,
                 jsonb_object_agg(altitudinal_zone::text, forest_type.json) AS json
          FROM projections_export
          LEFT JOIN forest_type USING (forest_ecoregion,
                                      altitudinal_zone)
          WHERE forest_type.json IS NOT NULL
          GROUP BY forest_ecoregion) SELECT jsonb_object_agg(forest_ecoregion::text, altitudinal_zone.json)
     FROM projections_export
     LEFT JOIN altitudinal_zone USING (forest_ecoregion)
     WHERE altitudinal_zone.json IS NOT NULL) To '/data/projections.json';

------------------------------
----- types

COPY
    (WITH additional AS
         (SELECT json_agg(jsonb_build_object('code', target, 'de', de)) AS
          values
          FROM additional_meta),
          altitudinal_zone AS
         (SELECT json_agg(jsonb_build_object('code', code, 'de', projection, 'id', id)) AS
          values
          FROM altitudinal_zone_meta),
          forest_ecoregions AS
         (SELECT json_agg(jsonb_build_object('code', subcode, 'de', region_de)) AS
          values
          FROM
              (SELECT subcode,
                            min(region_de) AS region_de
               FROM forest_ecoregions
               GROUP BY subcode
               ORDER BY subcode) foo),
          foresttype AS
         (SELECT json_agg(jsonb_build_object('code', code, 'de', de, 'height', CASE tree_layer_height_min is null
                                                                                   WHEN TRUE THEN null
                                                                                   ELSE jsonb_build_array(conifer_tree_height_max, deciduous_tree_height_max)
                                                                               END,
                                                                     'altitudinalZoneForestEcoregion',(SELECT json_agg(jsonb_build_array(altitudinal_zone_code, forest_ecoregion_code)) FROM foresttype_altitudinal_zone_forest_ecoregion WHERE foresttype_code = foresttype_meta.code GROUP BY foresttype_code),
                                                                     'carbonate', jsonb_build_array(carbonate_fine, carbonate_rock),
                                                                     'geomorphology', jsonb_build_array(geomorphology_rock_band, geomorphology_blocky_rocky_strong, geomorphology_blocky_rocky_little, geomorphology_limestone_pavement, geomorphology_rocks_moderately_moved, geomorphology_rocks_strongly_moved, geomorphology_rocks_stabilised),
                                                                     'reliefType', jsonb_build_array(relief_type_central_slope, relief_type_hollow, relief_type_dome, relief_type_plateau, relief_type_steep),
                                                                     'aspect', (SELECT json_agg(aspect) FROM foresttype_aspect WHERE foresttype_code = foresttype_meta.code GROUP BY foresttype_code),
                                                                     'slope', (SELECT json_agg(slope) FROM foresttype_slope WHERE foresttype_code = foresttype_meta.code GROUP BY foresttype_code),
                                                                     'group', jsonb_build_object('main',
                                                                                                                    (SELECT count(*) > 0
                                                                                                                     FROM foresttype_group
                                                                                                                     WHERE code = foresttype_meta.code
                                                                                                                         AND "group" = 'main'::foresttype_group_type), 'special',
                                                                                                                    (SELECT count(*) > 0
                                                                                                                     FROM foresttype_group
                                                                                                                     WHERE code = foresttype_meta.code
                                                                                                                         AND "group" = 'special'::foresttype_group_type), 'volatile',
                                                                                                                    (SELECT count(*) > 0
                                                                                                                     FROM foresttype_group
                                                                                                                     WHERE code = foresttype_meta.code
                                                                                                                         AND "group" = 'volatile'::foresttype_group_type), 'riverside',
                                                                                                                    (SELECT count(*) > 0
                                                                                                                     FROM foresttype_group
                                                                                                                     WHERE code = foresttype_meta.code
                                                                                                                         AND "group" = 'riverside'::foresttype_group_type), 'pioneer',
                                                                                                                    (SELECT count(*) > 0
                                                                                                                     FROM foresttype_group
                                                                                                                     WHERE code = foresttype_meta.code
                                                                                                                         AND "group" = 'pioneer'::foresttype_group_type)))
                          ORDER BY
                          sort) AS
          VALUES
          FROM foresttype_meta),
          indicators as
         (SELECT json_agg(jsonb_build_object('code', code, 'de', de, 'forestTypes',
                                                 (SELECT json_agg(trim(BOTH FROM naistyp_c))
                                                  FROM nat_naistyp_art
                                                  WHERE vorh IN ('1', '2', '3') AND sisf_nr::int = indicator_meta.code)
         )) AS
          values
          FROM indicator_meta),
          relief as
         (SELECT json_agg(jsonb_build_object('code', target, 'de', de)) AS
          values
          FROM
              (SELECT DISTINCT target,
                               de
               FROM relief_meta) foo),
          silver_fir_areas as
         (SELECT json_agg(jsonb_build_object('code', code_ta, 'de', projection)) AS
          values
          FROM silver_fir_area_meta),
          slope AS
         (SELECT json_agg(jsonb_build_object('code', target, 'de', de)) AS
          values
          FROM slope_meta),
          treetype AS
         (SELECT json_agg(jsonb_build_object('code', target::text::int, 'de', de, 'endangered', endangered, 'nonresident', nonresident, 'pioneer', pioneer, 'forestTypes',
                                                 (SELECT json_agg(trim(BOTH FROM naistyp_c))
                                                  FROM nat_naistyp_art
                                                  WHERE vorh IN ('1', '2', '3') AND sisf_nr::int::text = treetype_meta.target::text))) AS
          values
          FROM treetype_meta) SELECT jsonb_build_object('additional',additional.
                                                        values,'altitudinalZone',altitudinal_zone.
                                                        values,'forestEcoregion', forest_ecoregions.
                                                        values,'forestType', foresttype.
                                                        values,'indicator',indicators.
                                                        values,'relief',relief.
                                                        values,'silverFirArea',silver_fir_areas.
                                                        values,'slope',slope.
                                                        values,'treeType', treetype.
                                                        values)
     FROM additional,
          altitudinal_zone,
          forest_ecoregions,
          foresttype,
          indicators,
          relief,
          silver_fir_areas,
          slope,
          treetype) TO '/data/types.json';

     GET DIAGNOSTICS x = ROW_COUNT;
  RETURN x;
END;
$$ LANGUAGE plpgsql;