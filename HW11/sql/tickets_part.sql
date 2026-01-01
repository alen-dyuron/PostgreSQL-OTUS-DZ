-- bookings.tickets_part определение

-- DROP TABLE bookings.tickets_part ;
CREATE TABLE bookings.tickets_part (
	ticket_no text NOT NULL,
	book_ref bpchar(6) NOT NULL,
		book_date timestamptz NOT NULL, -- added to reference table BOOKINGS_PART
	passenger_id text NOT NULL,
	passenger_name text NOT NULL,
	outbound bool NOT NULL,
	CONSTRAINT tickets_part_book_ref_passenger_id_outbound_key UNIQUE (book_ref, passenger_id, outbound, passenger_name),
	CONSTRAINT tickets_part_pkey PRIMARY KEY (ticket_no, passenger_name)
) PARTITION BY HASH(passenger_name);
CREATE INDEX tickets_part_passenger_name ON bookings.tickets_part USING gin (passenger_name gin_trgm_ops);
CREATE INDEX tickets_part_passenger_uppername ON bookings.tickets_part USING btree (upper(passenger_name));

-- Permissions

ALTER TABLE bookings.tickets_part OWNER TO postgres;
GRANT ALL ON TABLE bookings.tickets_part TO postgres;

-- bookings.tickets_part внешние включи

ALTER TABLE bookings.tickets_part ADD CONSTRAINT tickets_part_book_ref_date_fkey FOREIGN KEY (book_ref, book_date) REFERENCES bookings.bookings_part(book_ref, book_date);

CREATE TABLE bookings.tickets_part_r0 PARTITION OF bookings.tickets_part FOR VALUES WITH (modulus 10, remainder 0);
CREATE TABLE bookings.tickets_part_r1 PARTITION OF bookings.tickets_part FOR VALUES WITH (modulus 10, remainder 1);
CREATE TABLE bookings.tickets_part_r2 PARTITION OF bookings.tickets_part FOR VALUES WITH (modulus 10, remainder 2);
CREATE TABLE bookings.tickets_part_r3 PARTITION OF bookings.tickets_part FOR VALUES WITH (modulus 10, remainder 3);
CREATE TABLE bookings.tickets_part_r4 PARTITION OF bookings.tickets_part FOR VALUES WITH (modulus 10, remainder 4);
CREATE TABLE bookings.tickets_part_r5 PARTITION OF bookings.tickets_part FOR VALUES WITH (modulus 10, remainder 5);
CREATE TABLE bookings.tickets_part_r6 PARTITION OF bookings.tickets_part FOR VALUES WITH (modulus 10, remainder 6);
CREATE TABLE bookings.tickets_part_r7 PARTITION OF bookings.tickets_part FOR VALUES WITH (modulus 10, remainder 7);
CREATE TABLE bookings.tickets_part_r8 PARTITION OF bookings.tickets_part FOR VALUES WITH (modulus 10, remainder 8);
CREATE TABLE bookings.tickets_part_r9 PARTITION OF bookings.tickets_part FOR VALUES WITH (modulus 10, remainder 9);
