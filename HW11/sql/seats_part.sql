-- bookings.seats_part определение

-- DROP TABLE bookings.seats_part;
CREATE TABLE bookings.seats_part (
	airplane_code bpchar(3) NOT NULL,
	seat_no text NOT NULL,
	fare_conditions text NOT NULL,
	CONSTRAINT seats_part_fare_conditions_check CHECK ((fare_conditions = ANY (ARRAY['Economy'::text, 'Comfort'::text, 'Business'::text]))),
	CONSTRAINT seats_part_pkey PRIMARY KEY (airplane_code, seat_no, fare_conditions)
) PARTITION BY LIST (fare_conditions);

-- Permissions

ALTER TABLE bookings.seats_part OWNER TO postgres;
GRANT ALL ON TABLE bookings.seats_part TO postgres;

-- Partitions

CREATE TABLE bookings.seats_part_bsn PARTITION OF bookings.seats_part FOR VALUES IN ('Business');
CREATE TABLE bookings.seats_part_cmf PARTITION OF bookings.seats_part FOR VALUES IN ('Comfort');
CREATE TABLE bookings.seats_part_eco PARTITION OF bookings.seats_part FOR VALUES IN ('Economy');

-- bookings.seats внешние включи

ALTER TABLE bookings.seats_part ADD CONSTRAINT seats_part_airplane_code_fkey FOREIGN KEY (airplane_code) REFERENCES bookings.airplanes_data(airplane_code) ON DELETE CASCADE;