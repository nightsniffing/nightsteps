UPDATE app_ldd.ns_base
SET change_to_housing = TRUE
FROM 
  (SELECT
    p.permission_id,
    sum(ex.number_of_units) AS ex_units,
    sum(pr.number_of_units) AS pr_units
  FROM
    (app_ldd.ld_permissions AS p LEFT JOIN
    app_ldd.ld_exist_res_lines AS ex
    ON p.permission_id = ex.permission_id)
      LEFT JOIN app_ldd.ld_prop_res_lines AS pr
      ON p.permission_id = pr.permission_id
  GROUP BY
    p.permission_id
  HAVING
    sum(ex.number_of_units) > 0
    OR sum(pr.number_of_units) > 0) AS h
WHERE
  app_ldd.ns_base.permission_id=h.permission_id

