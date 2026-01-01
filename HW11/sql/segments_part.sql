-- bookings.segments_part определение

-- DROP TABLE bookings.segments_part ;
CREATE TABLE bookings.segments_part (
	ticket_no text NOT NULL,
		passenger_name text NOT NULL, -- added to reference table TICKETS_PART
	flight_id int4 NOT NULL,
		scheduled_departure timestamptz NOT NULL, -- added to reference table FLIGHTS_PART
	fare_conditions text NOT NULL,
	price numeric(10, 2) NOT NULL,
	CONSTRAINT segments_part_fare_conditions_check CHECK ((fare_conditions = ANY (ARRAY['Economy'::text, 'Comfort'::text, 'Business'::text]))),
	CONSTRAINT segments_part_pkey PRIMARY KEY (ticket_no, flight_id, fare_conditions),
	CONSTRAINT segments_part_price_check CHECK ((price >= (0)::numeric))
) PARTITION BY LIST (fare_conditions);

CREATE INDEX segments_part_flight_id_idx ON bookings.segments_part USING btree (flight_id);

-- Permissions

ALTER TABLE bookings.segments_part OWNER TO postgres;
GRANT ALL ON TABLE bookings.segments_part TO postgres;

-- Partitions

CREATE TABLE bookings.segments_part_bsn PARTITION OF bookings.segments_part FOR VALUES IN ('Business');
CREATE TABLE bookings.segments_part_cmf PARTITION OF bookings.segments_part FOR VALUES IN ('Comfort');
CREATE TABLE bookings.segments_part_eco PARTITION OF bookings.segments_part FOR VALUES IN ('Economy');

-- Foreign Keys

ALTER TABLE bookings.segments_part ADD CONSTRAINT segments_part_flight_part_fkey FOREIGN KEY (flight_id,scheduled_departure) REFERENCES bookings.flights_part(flight_id,scheduled_departure);
ALTER TABLE bookings.segments_part ADD CONSTRAINT segments_part_ticket_no_fkey FOREIGN KEY (ticket_no,passenger_name) REFERENCES bookings.tickets_part(ticket_no,passenger_name);

