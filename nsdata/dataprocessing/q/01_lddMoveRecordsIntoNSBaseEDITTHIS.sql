/*This is the query you want to edit to customise which of the thousands of LDD records the datasniffer will use.
Running the datasniffer from this table instead of examining the whole database greatly improves performance.*/
INSERT INTO app_ldd.ns_base(
  permission_id,
  source,
  borough_ref,
  borough_name,
  ns_type,
  descr,
  completed_date,
  permission_date,
  status_rc
) 
SELECT
  p.permission_id,
  'lddJul2020',/*This is a record source identifier. Change it if you want something else.*/
  p.borough_ref,
  b.name,
  'major',/*This means the record will be picked up by the main filters. Don't change unless you know what you are doing.*/
  p.descr,
  p.completed_date,
  p.permission_date,
  p.status_rc
FROM
  ( 
    (
      app_ldd.ld_permissions AS p LEFT JOIN app_ldd.ns_permlatlon AS ll ON p.permission_id=ll.permission_id
    ) 
    LEFT JOIN app_ldd.ld_prop_res_lines AS prl_super ON p.permission_id=prl_super.superseded_permission_id
  )
  LEFT JOIN app_ldd.ld_boroughs AS b ON p.borough_id=b.borough_id
WHERE
  /*Insert your custom criteria here. It is better if the Nightsteps table (ns_base) doesn't contain literally every record in the LDD.*/
  (
    /*I have limited here for the boroughs I am looking at, you might want different boroughs*/
    b.name = 'Southwark' OR
    b.name = 'Lambeth' OR
    b.name = 'Islington'
  )
  AND
  (
    /*I have also limited it to applications that were completed from 2007 onwards, or those that are not completed.
    You might be interested in different records/criteria*/
    (
      p.status_rc = 'COMPLETED' AND
      p.completed_date > '01-01-2007'
    )
    OR
    (
      p.status_rc != 'COMPLETED'
    )
  )
GROUP BY
  p.permission_id,
  p.borough_ref,
  b.name,
  p.descr,
  p.completed_date,
  p.permission_date,
  p.status_rc
HAVING
  COUNT(prl_super.permission_id) = 0;
