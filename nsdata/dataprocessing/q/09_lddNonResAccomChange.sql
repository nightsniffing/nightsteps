UPDATE app_ldd.ns_base
SET change_to_nonresaccom = TRUE
FROM 
  (SELECT
    p.permission_id,
    sum(ex.accom) AS ex_accom,
    sum(pr.accom) AS pr_accom
  FROM
    (app_ldd.ld_permissions AS p LEFT JOIN
    app_ldd.ca_exist_non_res_accom AS ex
    ON p.permission_id = ex.permission_id)
      LEFT JOIN app_ldd.ca_prop_non_res_accom AS pr
      ON p.permission_id = pr.permission_id
  GROUP BY
    p.permission_id
  HAVING
    sum(ex.accom) > 0
    OR sum(pr.accom) > 0) AS h
WHERE
  app_ldd.ns_base.permission_id=h.permission_id

