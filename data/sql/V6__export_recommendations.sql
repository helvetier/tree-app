
CREATE TABLE recommendations_export (foresttype foresttype,
                                     treetype treetype,
                                     recommendationtype recommendationtype);


INSERT INTO recommendations_export (foresttype, treetype, recommendationtype)
SELECT trim(naistyp_c)::foresttype,
       sisf_nr::int::text::treetype,
       vorh::recommendationtype
FROM nat_naistyp_art
WHERE art = 'B'
        AND trim(naistyp_c::name) = any(enum_range(null::foresttype)::name[]);

COPY
        (WITH one AS
                 (SELECT foresttype,
                         json_agg(treetype::text::int) treetypes
                  FROM recommendations_export
                  WHERE recommendationtype = '1'
                  GROUP BY foresttype),
              two AS
                 (SELECT foresttype,
                         json_agg(treetype::text::int) treetypes
                  FROM recommendations_export
                  WHERE recommendationtype = '2'
                  GROUP BY foresttype),
              three AS
                 (SELECT foresttype,
                         json_agg(treetype::text::int) treetypes
                  FROM recommendations_export
                  WHERE recommendationtype = '3'
                  GROUP BY foresttype),
              four AS
                 (SELECT foresttype,
                         json_agg(treetype::text::int) treetypes
                  FROM recommendations_export
                  WHERE treetype = '9500'
                  GROUP BY foresttype) SELECT json_object_agg(foresttype,json_build_object('one',coalesce(one.treetypes,'[]'::json),'two',coalesce(two.treetypes,'[]'::json),'three',coalesce(three.treetypes,'[]'::json),'four',coalesce(four.treetypes,'[]'::json))) AS recommendations
         FROM
                 (SELECT DISTINCT foresttype
                  FROM recommendations_export) foo
         LEFT JOIN one USING (foresttype)
         LEFT JOIN two USING (foresttype)
         LEFT JOIN three USING (foresttype)
         LEFT JOIN four USING (foresttype)) TO '/data/recommendations.json';