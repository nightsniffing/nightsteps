UPDATE app_ldd.ns_base
SET change_to_floorspace = TRUE
FROM 
  (SELECT
    p.permission_id,
    sum(ex.floorspace) AS ex_floorspace,
    sum(pr.floorspace) AS pr_floorspace
  FROM
    (app_ldd.ld_permissions AS p LEFT JOIN
    app_ldd.ca_exist_non_res_floorspace AS ex
    ON p.permission_id = ex.permission_id)
      LEFT JOIN app_ldd.ca_prop_non_res_floorspace AS pr
      ON p.permission_id = pr.permission_id
  GROUP BY
    p.permission_id
  HAVING
    sum(ex.floorspace) > 0
    OR sum(pr.floorspace) > 0) AS h
WHERE
  app_ldd.ns_base.permission_id=h.permission_id

