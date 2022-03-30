UPDATE app_ldd.ns_base
SET lat=ll.lat,
    lon=ll.lon
FROM app_ldd.ns_permlatlon AS ll
WHERE app_ldd.ns_base.permission_id=ll.permission_id;


