-- bookings.flights_part определение

-- DROP TABLE bookings.flights_part;
CREATE TABLE bookings.flights_part (
	flight_id int4 GENERATED ALWAYS AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 NO CYCLE) NOT NULL,
	route_no text NOT NULL,
	status text NOT NULL,
	scheduled_departure timestamptz NOT NULL,
	scheduled_arrival timestamptz NOT NULL,
	actual_departure timestamptz NULL,
	actual_arrival timestamptz NULL,
	CONSTRAINT flights_part_actual_check CHECK (((actual_arrival IS NULL) OR ((actual_departure IS NOT NULL) AND (actual_arrival IS NOT NULL) AND (actual_arrival > actual_departure)))),
	CONSTRAINT flights_part_scheduled_check CHECK ((scheduled_arrival > scheduled_departure)),
	CONSTRAINT flights_part_status_check CHECK ((status = ANY (ARRAY['Scheduled'::text, 'On Time'::text, 'Delayed'::text, 'Boarding'::text, 'Departed'::text, 'Arrived'::text, 'Cancelled'::text]))),
	CONSTRAINT flights_part_pkey PRIMARY KEY (flight_id, scheduled_departure),
	CONSTRAINT flights_part_route_no_scheduled_departure_key UNIQUE (route_no, scheduled_departure)
) PARTITION BY RANGE(scheduled_departure);

CREATE INDEX flights_part_status_dep_arr ON bookings.flights_part USING btree (status, actual_departure, actual_arrival);

-- Permissions

ALTER TABLE bookings.flights_part OWNER TO postgres;
GRANT ALL ON TABLE bookings.flights_part TO postgres;

-- Partitions
--  2025-10-01 00:00:00+00 | 2026-01-29 23:55:00+00

CREATE TABLE bookings.flights_part_20251001 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-01'::timestamptz) TO ('2025-10-02'::timestamptz);
CREATE TABLE bookings.flights_part_20251002 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-02'::timestamptz) TO ('2025-10-03'::timestamptz);
CREATE TABLE bookings.flights_part_20251003 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-03'::timestamptz) TO ('2025-10-04'::timestamptz);
CREATE TABLE bookings.flights_part_20251004 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-04'::timestamptz) TO ('2025-10-05'::timestamptz);
CREATE TABLE bookings.flights_part_20251005 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-05'::timestamptz) TO ('2025-10-06'::timestamptz);
CREATE TABLE bookings.flights_part_20251006 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-06'::timestamptz) TO ('2025-10-07'::timestamptz);
CREATE TABLE bookings.flights_part_20251007 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-07'::timestamptz) TO ('2025-10-08'::timestamptz);
CREATE TABLE bookings.flights_part_20251008 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-08'::timestamptz) TO ('2025-10-09'::timestamptz);
CREATE TABLE bookings.flights_part_20251009 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-09'::timestamptz) TO ('2025-10-10'::timestamptz);
CREATE TABLE bookings.flights_part_20251010 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-10'::timestamptz) TO ('2025-10-11'::timestamptz);
CREATE TABLE bookings.flights_part_20251011 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-11'::timestamptz) TO ('2025-10-12'::timestamptz);
CREATE TABLE bookings.flights_part_20251012 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-12'::timestamptz) TO ('2025-10-13'::timestamptz);
CREATE TABLE bookings.flights_part_20251013 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-13'::timestamptz) TO ('2025-10-14'::timestamptz);
CREATE TABLE bookings.flights_part_20251014 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-14'::timestamptz) TO ('2025-10-15'::timestamptz);
CREATE TABLE bookings.flights_part_20251015 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-15'::timestamptz) TO ('2025-10-16'::timestamptz);
CREATE TABLE bookings.flights_part_20251016 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-16'::timestamptz) TO ('2025-10-17'::timestamptz);
CREATE TABLE bookings.flights_part_20251017 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-17'::timestamptz) TO ('2025-10-18'::timestamptz);
CREATE TABLE bookings.flights_part_20251018 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-18'::timestamptz) TO ('2025-10-19'::timestamptz);
CREATE TABLE bookings.flights_part_20251019 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-19'::timestamptz) TO ('2025-10-20'::timestamptz);
CREATE TABLE bookings.flights_part_20251020 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-20'::timestamptz) TO ('2025-10-21'::timestamptz);
CREATE TABLE bookings.flights_part_20251021 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-21'::timestamptz) TO ('2025-10-22'::timestamptz);
CREATE TABLE bookings.flights_part_20251022 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-22'::timestamptz) TO ('2025-10-23'::timestamptz);
CREATE TABLE bookings.flights_part_20251023 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-23'::timestamptz) TO ('2025-10-24'::timestamptz);
CREATE TABLE bookings.flights_part_20251024 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-24'::timestamptz) TO ('2025-10-25'::timestamptz);
CREATE TABLE bookings.flights_part_20251025 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-25'::timestamptz) TO ('2025-10-26'::timestamptz);
CREATE TABLE bookings.flights_part_20251026 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-26'::timestamptz) TO ('2025-10-27'::timestamptz);
CREATE TABLE bookings.flights_part_20251027 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-27'::timestamptz) TO ('2025-10-28'::timestamptz);
CREATE TABLE bookings.flights_part_20251028 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-28'::timestamptz) TO ('2025-10-29'::timestamptz);
CREATE TABLE bookings.flights_part_20251029 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-29'::timestamptz) TO ('2025-10-30'::timestamptz);
CREATE TABLE bookings.flights_part_20251030 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-30'::timestamptz) TO ('2025-10-31'::timestamptz);
CREATE TABLE bookings.flights_part_20251031 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-10-31'::timestamptz) TO ('2025-11-01'::timestamptz);
CREATE TABLE bookings.flights_part_20251101 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-01'::timestamptz) TO ('2025-11-02'::timestamptz);
CREATE TABLE bookings.flights_part_20251102 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-02'::timestamptz) TO ('2025-11-03'::timestamptz);
CREATE TABLE bookings.flights_part_20251103 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-03'::timestamptz) TO ('2025-11-04'::timestamptz);
CREATE TABLE bookings.flights_part_20251104 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-04'::timestamptz) TO ('2025-11-05'::timestamptz);
CREATE TABLE bookings.flights_part_20251105 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-05'::timestamptz) TO ('2025-11-06'::timestamptz);
CREATE TABLE bookings.flights_part_20251106 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-06'::timestamptz) TO ('2025-11-07'::timestamptz);
CREATE TABLE bookings.flights_part_20251107 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-07'::timestamptz) TO ('2025-11-08'::timestamptz);
CREATE TABLE bookings.flights_part_20251108 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-08'::timestamptz) TO ('2025-11-09'::timestamptz);
CREATE TABLE bookings.flights_part_20251109 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-09'::timestamptz) TO ('2025-11-10'::timestamptz);
CREATE TABLE bookings.flights_part_20251110 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-10'::timestamptz) TO ('2025-11-11'::timestamptz);
CREATE TABLE bookings.flights_part_20251111 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-11'::timestamptz) TO ('2025-11-12'::timestamptz);
CREATE TABLE bookings.flights_part_20251112 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-12'::timestamptz) TO ('2025-11-13'::timestamptz);
CREATE TABLE bookings.flights_part_20251113 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-13'::timestamptz) TO ('2025-11-14'::timestamptz);
CREATE TABLE bookings.flights_part_20251114 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-14'::timestamptz) TO ('2025-11-15'::timestamptz);
CREATE TABLE bookings.flights_part_20251115 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-15'::timestamptz) TO ('2025-11-16'::timestamptz);
CREATE TABLE bookings.flights_part_20251116 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-16'::timestamptz) TO ('2025-11-17'::timestamptz);
CREATE TABLE bookings.flights_part_20251117 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-17'::timestamptz) TO ('2025-11-18'::timestamptz);
CREATE TABLE bookings.flights_part_20251118 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-18'::timestamptz) TO ('2025-11-19'::timestamptz);
CREATE TABLE bookings.flights_part_20251119 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-19'::timestamptz) TO ('2025-11-20'::timestamptz);
CREATE TABLE bookings.flights_part_20251120 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-20'::timestamptz) TO ('2025-11-21'::timestamptz);
CREATE TABLE bookings.flights_part_20251121 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-21'::timestamptz) TO ('2025-11-22'::timestamptz);
CREATE TABLE bookings.flights_part_20251122 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-22'::timestamptz) TO ('2025-11-23'::timestamptz);
CREATE TABLE bookings.flights_part_20251123 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-23'::timestamptz) TO ('2025-11-24'::timestamptz);
CREATE TABLE bookings.flights_part_20251124 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-24'::timestamptz) TO ('2025-11-25'::timestamptz);
CREATE TABLE bookings.flights_part_20251125 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-25'::timestamptz) TO ('2025-11-26'::timestamptz);
CREATE TABLE bookings.flights_part_20251126 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-26'::timestamptz) TO ('2025-11-27'::timestamptz);
CREATE TABLE bookings.flights_part_20251127 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-27'::timestamptz) TO ('2025-11-28'::timestamptz);
CREATE TABLE bookings.flights_part_20251128 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-28'::timestamptz) TO ('2025-11-29'::timestamptz);
CREATE TABLE bookings.flights_part_20251129 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-29'::timestamptz) TO ('2025-11-30'::timestamptz);
CREATE TABLE bookings.flights_part_20251130 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-11-30'::timestamptz) TO ('2025-12-01'::timestamptz);
CREATE TABLE bookings.flights_part_20251201 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-01'::timestamptz) TO ('2025-12-02'::timestamptz);
CREATE TABLE bookings.flights_part_20251202 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-02'::timestamptz) TO ('2025-12-03'::timestamptz);
CREATE TABLE bookings.flights_part_20251203 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-03'::timestamptz) TO ('2025-12-04'::timestamptz);
CREATE TABLE bookings.flights_part_20251204 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-04'::timestamptz) TO ('2025-12-05'::timestamptz);
CREATE TABLE bookings.flights_part_20251205 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-05'::timestamptz) TO ('2025-12-06'::timestamptz);
CREATE TABLE bookings.flights_part_20251206 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-06'::timestamptz) TO ('2025-12-07'::timestamptz);
CREATE TABLE bookings.flights_part_20251207 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-07'::timestamptz) TO ('2025-12-08'::timestamptz);
CREATE TABLE bookings.flights_part_20251208 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-08'::timestamptz) TO ('2025-12-09'::timestamptz);
CREATE TABLE bookings.flights_part_20251209 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-09'::timestamptz) TO ('2025-12-10'::timestamptz);
CREATE TABLE bookings.flights_part_20251210 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-10'::timestamptz) TO ('2025-12-11'::timestamptz);
CREATE TABLE bookings.flights_part_20251211 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-11'::timestamptz) TO ('2025-12-12'::timestamptz);
CREATE TABLE bookings.flights_part_20251212 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-12'::timestamptz) TO ('2025-12-13'::timestamptz);
CREATE TABLE bookings.flights_part_20251213 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-13'::timestamptz) TO ('2025-12-14'::timestamptz);
CREATE TABLE bookings.flights_part_20251214 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-14'::timestamptz) TO ('2025-12-15'::timestamptz);
CREATE TABLE bookings.flights_part_20251215 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-15'::timestamptz) TO ('2025-12-16'::timestamptz);
CREATE TABLE bookings.flights_part_20251216 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-16'::timestamptz) TO ('2025-12-17'::timestamptz);
CREATE TABLE bookings.flights_part_20251217 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-17'::timestamptz) TO ('2025-12-18'::timestamptz);
CREATE TABLE bookings.flights_part_20251218 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-18'::timestamptz) TO ('2025-12-19'::timestamptz);
CREATE TABLE bookings.flights_part_20251219 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-19'::timestamptz) TO ('2025-12-20'::timestamptz);
CREATE TABLE bookings.flights_part_20251220 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-20'::timestamptz) TO ('2025-12-21'::timestamptz);
CREATE TABLE bookings.flights_part_20251221 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-21'::timestamptz) TO ('2025-12-22'::timestamptz);
CREATE TABLE bookings.flights_part_20251222 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-22'::timestamptz) TO ('2025-12-23'::timestamptz);
CREATE TABLE bookings.flights_part_20251223 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-23'::timestamptz) TO ('2025-12-24'::timestamptz);
CREATE TABLE bookings.flights_part_20251224 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-24'::timestamptz) TO ('2025-12-25'::timestamptz);
CREATE TABLE bookings.flights_part_20251225 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-25'::timestamptz) TO ('2025-12-26'::timestamptz);
CREATE TABLE bookings.flights_part_20251226 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-26'::timestamptz) TO ('2025-12-27'::timestamptz);
CREATE TABLE bookings.flights_part_20251227 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-27'::timestamptz) TO ('2025-12-28'::timestamptz);
CREATE TABLE bookings.flights_part_20251228 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-28'::timestamptz) TO ('2025-12-29'::timestamptz);
CREATE TABLE bookings.flights_part_20251229 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-29'::timestamptz) TO ('2025-12-30'::timestamptz);
CREATE TABLE bookings.flights_part_20251230 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-30'::timestamptz) TO ('2025-12-31'::timestamptz);
CREATE TABLE bookings.flights_part_20251231 PARTITION OF bookings.flights_part FOR VALUES FROM ('2025-12-31'::timestamptz) TO ('2026-01-01'::timestamptz);
CREATE TABLE bookings.flights_part_20260101 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-01'::timestamptz) TO ('2026-01-02'::timestamptz);
CREATE TABLE bookings.flights_part_20260102 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-02'::timestamptz) TO ('2026-01-03'::timestamptz);
CREATE TABLE bookings.flights_part_20260103 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-03'::timestamptz) TO ('2026-01-04'::timestamptz);
CREATE TABLE bookings.flights_part_20260104 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-04'::timestamptz) TO ('2026-01-05'::timestamptz);
CREATE TABLE bookings.flights_part_20260105 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-05'::timestamptz) TO ('2026-01-06'::timestamptz);
CREATE TABLE bookings.flights_part_20260106 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-06'::timestamptz) TO ('2026-01-07'::timestamptz);
CREATE TABLE bookings.flights_part_20260107 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-07'::timestamptz) TO ('2026-01-08'::timestamptz);
CREATE TABLE bookings.flights_part_20260108 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-08'::timestamptz) TO ('2026-01-09'::timestamptz);
CREATE TABLE bookings.flights_part_20260109 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-09'::timestamptz) TO ('2026-01-10'::timestamptz);
CREATE TABLE bookings.flights_part_20260110 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-10'::timestamptz) TO ('2026-01-11'::timestamptz);
CREATE TABLE bookings.flights_part_20260111 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-11'::timestamptz) TO ('2026-01-12'::timestamptz);
CREATE TABLE bookings.flights_part_20260112 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-12'::timestamptz) TO ('2026-01-13'::timestamptz);
CREATE TABLE bookings.flights_part_20260113 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-13'::timestamptz) TO ('2026-01-14'::timestamptz);
CREATE TABLE bookings.flights_part_20260114 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-14'::timestamptz) TO ('2026-01-15'::timestamptz);
CREATE TABLE bookings.flights_part_20260115 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-15'::timestamptz) TO ('2026-01-16'::timestamptz);
CREATE TABLE bookings.flights_part_20260116 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-16'::timestamptz) TO ('2026-01-17'::timestamptz);
CREATE TABLE bookings.flights_part_20260117 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-17'::timestamptz) TO ('2026-01-18'::timestamptz);
CREATE TABLE bookings.flights_part_20260118 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-18'::timestamptz) TO ('2026-01-19'::timestamptz);
CREATE TABLE bookings.flights_part_20260119 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-19'::timestamptz) TO ('2026-01-20'::timestamptz);
CREATE TABLE bookings.flights_part_20260120 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-20'::timestamptz) TO ('2026-01-21'::timestamptz);
CREATE TABLE bookings.flights_part_20260121 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-21'::timestamptz) TO ('2026-01-22'::timestamptz);
CREATE TABLE bookings.flights_part_20260122 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-22'::timestamptz) TO ('2026-01-23'::timestamptz);
CREATE TABLE bookings.flights_part_20260123 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-23'::timestamptz) TO ('2026-01-24'::timestamptz);
CREATE TABLE bookings.flights_part_20260124 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-24'::timestamptz) TO ('2026-01-25'::timestamptz);
CREATE TABLE bookings.flights_part_20260125 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-25'::timestamptz) TO ('2026-01-26'::timestamptz);
CREATE TABLE bookings.flights_part_20260126 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-26'::timestamptz) TO ('2026-01-27'::timestamptz);
CREATE TABLE bookings.flights_part_20260127 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-27'::timestamptz) TO ('2026-01-28'::timestamptz);
CREATE TABLE bookings.flights_part_20260128 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-28'::timestamptz) TO ('2026-01-29'::timestamptz);
CREATE TABLE bookings.flights_part_20260129 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-29'::timestamptz) TO ('2026-01-30'::timestamptz);
CREATE TABLE bookings.flights_part_20260130 PARTITION OF bookings.flights_part FOR VALUES FROM ('2026-01-30'::timestamptz) TO ('2026-11-01'::timestamptz);
CREATE TABLE bookings.flights_part_default PARTITION OF bookings.flights_part DEFAULT;

