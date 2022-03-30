UPDATE app_ldd.ns_base
SET sitearea_total=sitearea.area
FROM 
  (SELECT
    p.permission_id,
    COALESCE(SUM(pos.area),0) + COALESCE(p.proposed_net_site_area,0) + COALESCE(p.gross_area,0) AS area
  FROM
    app_ldd.ld_permissions AS p LEFT JOIN
    app_ldd.ld_prop_open_space_lines AS pos
    ON p.permission_id = pos.permission_id
  GROUP BY
    p.permission_id) AS sitearea
WHERE
  app_ldd.ns_base.permission_id=sitearea.permission_id

