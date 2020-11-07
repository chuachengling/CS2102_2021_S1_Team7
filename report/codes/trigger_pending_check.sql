CREATE OR REPLACE FUNCTION trigger_pending_check()
RETURNS TRIGGER AS
$$
BEGIN
	-- Reject all other pending bids in an overlapping period, if an 'Accepted' status is updated/inserted for a specific pet
	IF NEW.status = 'Accepted' THEN
		UPDATE Looking_After la
		SET status = 'Rejected'
		WHERE la.po_userid = NEW.po_userid AND la.pet_name = NEW.pet_name AND la.status = 'Pending'
		AND NOT (la.start_date < NEW.start_date AND la.end_date < NEW.start_date)
		AND NOT (la.start_date > NEW.end_date AND la.end_date > NEW.end_date);
	END IF
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS cancel_pending_bids ON Looking_After;

CREATE TRIGGER cancel_pending_bids AFTER UPDATE OR INSERT ON Looking_After
FOR EACH ROW EXECUTE PROCEDURE trigger_pending_check();