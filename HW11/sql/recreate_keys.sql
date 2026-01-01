-- Adding the column to reference
ALTER TABLE bookings.boarding_passes ADD COLUMN fare_conditions text;

-- Updating it with reference data
UPDATE bookings.boarding_passes b
set fare_conditions = sub.fare_conditions 
from (
    select fare_conditions, ticket_no, flight_id
    from segments
) as sub
where 
b.ticket_no = sub.ticket_no and 
b.flight_id = sub.flight_id;

-- Creating new FK
ALTER TABLE bookings.boarding_passes 
	ADD CONSTRAINT boarding_passes_tickets_part_no_flight_id_fkey 
	FOREIGN KEY (ticket_no, flight_id, fare_conditions) REFERENCES segments_part(ticket_no, flight_id, fare_conditions);

-- Adding the initial check
ALTER TABLE bookings.boarding_passes ADD CONSTRAINT chk_fare_conditions_nn CHECK (fare_conditions IS NOT NULL);