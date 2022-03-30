UPDATE app_ldd.ns_base
SET proposed_socialhousing=h.units
FROM 
  (SELECT
    p.permission_id,
    sum(number_of_units) AS units
  FROM
    app_ldd.ld_permissions AS p LEFT JOIN
    app_ldd.ld_prop_res_lines AS res
    ON p.permission_id = res.permission_id
  WHERE
    tenure_type_rc='S'
  GROUP BY
    p.permission_id) AS h
WHERE
  app_ldd.ns_base.permission_id=h.permission_id

