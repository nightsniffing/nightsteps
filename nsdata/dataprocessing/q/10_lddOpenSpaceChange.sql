UPDATE app_ldd.ns_base
SET change_to_openspace = TRUE
FROM 
  (SELECT
    p.permission_id,
    sum(ex.area) AS ex_area,
    sum(pr.area) AS pr_area
  FROM
    (app_ldd.ld_permissions AS p LEFT JOIN
    app_ldd.ld_exist_open_space_lines AS ex
    ON p.permission_id = ex.permission_id)
      LEFT JOIN app_ldd.ld_prop_open_space_lines AS pr
      ON p.permission_id = pr.permission_id
  GROUP BY
    p.permission_id
  HAVING
    sum(ex.area) > 0.0
    OR sum(pr.area) > 0.0) AS h
WHERE
  app_ldd.ns_base.permission_id=h.permission_id

