-- bookings.bookings определение

-- DROP TABLE bookings.bookings_part;
CREATE TABLE bookings.bookings_part (
	book_ref bpchar(6) NOT NULL,
	book_date timestamptz NOT NULL,
	total_amount numeric(10, 2) NOT NULL,
	CONSTRAINT bookings_part_pkey PRIMARY KEY (book_ref, book_date)
) PARTITION BY RANGE(book_date);

-- Permissions

ALTER TABLE bookings.bookings_part OWNER TO postgres;
GRANT ALL ON TABLE bookings.bookings_part TO postgres;

-- Partitions
-- 2025-09-01 03:00:06.265 +0300|2025-12-01 02:59:28.616 +0300|

CREATE TABLE bookings_part_20250901 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-01'::timestamptz) TO ('2025-09-02'::timestamptz);
CREATE TABLE bookings_part_20250902 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-02'::timestamptz) TO ('2025-09-03'::timestamptz);
CREATE TABLE bookings_part_20250903 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-03'::timestamptz) TO ('2025-09-04'::timestamptz);
CREATE TABLE bookings_part_20250904 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-04'::timestamptz) TO ('2025-09-05'::timestamptz);
CREATE TABLE bookings_part_20250905 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-05'::timestamptz) TO ('2025-09-06'::timestamptz);
CREATE TABLE bookings_part_20250906 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-06'::timestamptz) TO ('2025-09-07'::timestamptz);
CREATE TABLE bookings_part_20250907 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-07'::timestamptz) TO ('2025-09-08'::timestamptz);
CREATE TABLE bookings_part_20250908 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-08'::timestamptz) TO ('2025-09-09'::timestamptz);
CREATE TABLE bookings_part_20250909 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-09'::timestamptz) TO ('2025-09-10'::timestamptz);
CREATE TABLE bookings_part_20250910 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-10'::timestamptz) TO ('2025-09-11'::timestamptz);
CREATE TABLE bookings_part_20250911 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-11'::timestamptz) TO ('2025-09-12'::timestamptz);
CREATE TABLE bookings_part_20250912 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-12'::timestamptz) TO ('2025-09-13'::timestamptz);
CREATE TABLE bookings_part_20250913 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-13'::timestamptz) TO ('2025-09-14'::timestamptz);
CREATE TABLE bookings_part_20250914 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-14'::timestamptz) TO ('2025-09-15'::timestamptz);
CREATE TABLE bookings_part_20250915 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-15'::timestamptz) TO ('2025-09-16'::timestamptz);
CREATE TABLE bookings_part_20250916 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-16'::timestamptz) TO ('2025-09-17'::timestamptz);
CREATE TABLE bookings_part_20250917 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-17'::timestamptz) TO ('2025-09-18'::timestamptz);
CREATE TABLE bookings_part_20250918 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-18'::timestamptz) TO ('2025-09-19'::timestamptz);
CREATE TABLE bookings_part_20250919 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-19'::timestamptz) TO ('2025-09-20'::timestamptz);
CREATE TABLE bookings_part_20250920 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-20'::timestamptz) TO ('2025-09-21'::timestamptz);
CREATE TABLE bookings_part_20250921 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-21'::timestamptz) TO ('2025-09-22'::timestamptz);
CREATE TABLE bookings_part_20250922 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-22'::timestamptz) TO ('2025-09-23'::timestamptz);
CREATE TABLE bookings_part_20250923 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-23'::timestamptz) TO ('2025-09-24'::timestamptz);
CREATE TABLE bookings_part_20250924 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-24'::timestamptz) TO ('2025-09-25'::timestamptz);
CREATE TABLE bookings_part_20250925 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-25'::timestamptz) TO ('2025-09-26'::timestamptz);
CREATE TABLE bookings_part_20250926 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-26'::timestamptz) TO ('2025-09-27'::timestamptz);
CREATE TABLE bookings_part_20250927 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-27'::timestamptz) TO ('2025-09-28'::timestamptz);
CREATE TABLE bookings_part_20250928 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-28'::timestamptz) TO ('2025-09-29'::timestamptz);
CREATE TABLE bookings_part_20250929 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-29'::timestamptz) TO ('2025-09-30'::timestamptz);
CREATE TABLE bookings_part_20250930 PARTITION OF bookings_part FOR VALUES FROM ('2025-09-30'::timestamptz) TO ('2025-10-01'::timestamptz);
CREATE TABLE bookings_part_20251001 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-01'::timestamptz) TO ('2025-10-02'::timestamptz);
CREATE TABLE bookings_part_20251002 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-02'::timestamptz) TO ('2025-10-03'::timestamptz);
CREATE TABLE bookings_part_20251003 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-03'::timestamptz) TO ('2025-10-04'::timestamptz);
CREATE TABLE bookings_part_20251004 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-04'::timestamptz) TO ('2025-10-05'::timestamptz);
CREATE TABLE bookings_part_20251005 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-05'::timestamptz) TO ('2025-10-06'::timestamptz);
CREATE TABLE bookings_part_20251006 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-06'::timestamptz) TO ('2025-10-07'::timestamptz);
CREATE TABLE bookings_part_20251007 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-07'::timestamptz) TO ('2025-10-08'::timestamptz);
CREATE TABLE bookings_part_20251008 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-08'::timestamptz) TO ('2025-10-09'::timestamptz);
CREATE TABLE bookings_part_20251009 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-09'::timestamptz) TO ('2025-10-10'::timestamptz);
CREATE TABLE bookings_part_20251010 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-10'::timestamptz) TO ('2025-10-11'::timestamptz);
CREATE TABLE bookings_part_20251011 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-11'::timestamptz) TO ('2025-10-12'::timestamptz);
CREATE TABLE bookings_part_20251012 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-12'::timestamptz) TO ('2025-10-13'::timestamptz);
CREATE TABLE bookings_part_20251013 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-13'::timestamptz) TO ('2025-10-14'::timestamptz);
CREATE TABLE bookings_part_20251014 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-14'::timestamptz) TO ('2025-10-15'::timestamptz);
CREATE TABLE bookings_part_20251015 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-15'::timestamptz) TO ('2025-10-16'::timestamptz);
CREATE TABLE bookings_part_20251016 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-16'::timestamptz) TO ('2025-10-17'::timestamptz);
CREATE TABLE bookings_part_20251017 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-17'::timestamptz) TO ('2025-10-18'::timestamptz);
CREATE TABLE bookings_part_20251018 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-18'::timestamptz) TO ('2025-10-19'::timestamptz);
CREATE TABLE bookings_part_20251019 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-19'::timestamptz) TO ('2025-10-20'::timestamptz);
CREATE TABLE bookings_part_20251020 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-20'::timestamptz) TO ('2025-10-21'::timestamptz);
CREATE TABLE bookings_part_20251021 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-21'::timestamptz) TO ('2025-10-22'::timestamptz);
CREATE TABLE bookings_part_20251022 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-22'::timestamptz) TO ('2025-10-23'::timestamptz);
CREATE TABLE bookings_part_20251023 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-23'::timestamptz) TO ('2025-10-24'::timestamptz);
CREATE TABLE bookings_part_20251024 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-24'::timestamptz) TO ('2025-10-25'::timestamptz);
CREATE TABLE bookings_part_20251025 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-25'::timestamptz) TO ('2025-10-26'::timestamptz);
CREATE TABLE bookings_part_20251026 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-26'::timestamptz) TO ('2025-10-27'::timestamptz);
CREATE TABLE bookings_part_20251027 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-27'::timestamptz) TO ('2025-10-28'::timestamptz);
CREATE TABLE bookings_part_20251028 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-28'::timestamptz) TO ('2025-10-29'::timestamptz);
CREATE TABLE bookings_part_20251029 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-29'::timestamptz) TO ('2025-10-30'::timestamptz);
CREATE TABLE bookings_part_20251030 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-30'::timestamptz) TO ('2025-10-31'::timestamptz);
CREATE TABLE bookings_part_20251031 PARTITION OF bookings_part FOR VALUES FROM ('2025-10-31'::timestamptz) TO ('2025-11-01'::timestamptz);
CREATE TABLE bookings_part_20251101 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-01'::timestamptz) TO ('2025-11-02'::timestamptz);
CREATE TABLE bookings_part_20251102 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-02'::timestamptz) TO ('2025-11-03'::timestamptz);
CREATE TABLE bookings_part_20251103 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-03'::timestamptz) TO ('2025-11-04'::timestamptz);
CREATE TABLE bookings_part_20251104 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-04'::timestamptz) TO ('2025-11-05'::timestamptz);
CREATE TABLE bookings_part_20251105 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-05'::timestamptz) TO ('2025-11-06'::timestamptz);
CREATE TABLE bookings_part_20251106 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-06'::timestamptz) TO ('2025-11-07'::timestamptz);
CREATE TABLE bookings_part_20251107 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-07'::timestamptz) TO ('2025-11-08'::timestamptz);
CREATE TABLE bookings_part_20251108 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-08'::timestamptz) TO ('2025-11-09'::timestamptz);
CREATE TABLE bookings_part_20251109 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-09'::timestamptz) TO ('2025-11-10'::timestamptz);
CREATE TABLE bookings_part_20251110 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-10'::timestamptz) TO ('2025-11-11'::timestamptz);
CREATE TABLE bookings_part_20251111 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-11'::timestamptz) TO ('2025-11-12'::timestamptz);
CREATE TABLE bookings_part_20251112 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-12'::timestamptz) TO ('2025-11-13'::timestamptz);
CREATE TABLE bookings_part_20251113 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-13'::timestamptz) TO ('2025-11-14'::timestamptz);
CREATE TABLE bookings_part_20251114 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-14'::timestamptz) TO ('2025-11-15'::timestamptz);
CREATE TABLE bookings_part_20251115 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-15'::timestamptz) TO ('2025-11-16'::timestamptz);
CREATE TABLE bookings_part_20251116 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-16'::timestamptz) TO ('2025-11-17'::timestamptz);
CREATE TABLE bookings_part_20251117 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-17'::timestamptz) TO ('2025-11-18'::timestamptz);
CREATE TABLE bookings_part_20251118 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-18'::timestamptz) TO ('2025-11-19'::timestamptz);
CREATE TABLE bookings_part_20251119 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-19'::timestamptz) TO ('2025-11-20'::timestamptz);
CREATE TABLE bookings_part_20251120 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-20'::timestamptz) TO ('2025-11-21'::timestamptz);
CREATE TABLE bookings_part_20251121 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-21'::timestamptz) TO ('2025-11-22'::timestamptz);
CREATE TABLE bookings_part_20251122 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-22'::timestamptz) TO ('2025-11-23'::timestamptz);
CREATE TABLE bookings_part_20251123 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-23'::timestamptz) TO ('2025-11-24'::timestamptz);
CREATE TABLE bookings_part_20251124 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-24'::timestamptz) TO ('2025-11-25'::timestamptz);
CREATE TABLE bookings_part_20251125 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-25'::timestamptz) TO ('2025-11-26'::timestamptz);
CREATE TABLE bookings_part_20251126 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-26'::timestamptz) TO ('2025-11-27'::timestamptz);
CREATE TABLE bookings_part_20251127 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-27'::timestamptz) TO ('2025-11-28'::timestamptz);
CREATE TABLE bookings_part_20251128 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-28'::timestamptz) TO ('2025-11-29'::timestamptz);
CREATE TABLE bookings_part_20251129 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-29'::timestamptz) TO ('2025-11-30'::timestamptz);
CREATE TABLE bookings_part_20251130 PARTITION OF bookings_part FOR VALUES FROM ('2025-11-30'::timestamptz) TO ('2025-12-01'::timestamptz);
CREATE TABLE bookings_part_20251201 PARTITION OF bookings_part FOR VALUES FROM ('2025-12-01'::timestamptz) TO ('2025-12-02'::timestamptz);
CREATE TABLE bookings_part_20251202 PARTITION OF bookings_part FOR VALUES FROM ('2025-12-02'::timestamptz) TO ('2025-12-03'::timestamptz);
CREATE TABLE bookings_part_default PARTITION OF bookings_part DEFAULT;

