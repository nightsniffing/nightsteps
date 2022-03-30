UPDATE app_ldd.ns_base
SET the_geom_poly=geo.the_geom,
    the_geom_pt=geo.the_geom_pt
FROM app_ldd.nsll_ld_permissions_geo AS geo
WHERE app_ldd.ns_base.permission_id=geo.objectid;


