CREATE OR REPLACE FUNCTION trigger_ft_leave_check()
RETURNS TRIGGER AS
$$
BEGIN
	DROP TABLE IF EXISTS leave_records;
	DROP TABLE IF EXISTS days_avail;

	-- Has all leave records for the user being inserted
	CREATE TEMPORARY TABLE leave_records AS (
		SELECT ftl.leave_sd, ftl.leave_ed
		FROM FT_Leave ftl
		WHERE NEW.ct_userid = ftl.ct_userid
	); 

	-- Disallow leave application if caretaker would already be on leave
  	IF (SELECT EXISTS(SELECT 1 FROM leave_records lr2
  		WHERE NEW.leave_sd BETWEEN SYMMETRIC lr2.leave_ed AND lr2.leave_sd))
	OR (SELECT EXISTS(SELECT 1 FROM leave_records lr2
		WHERE NEW.leave_ed BETWEEN SYMMETRIC lr2.leave_ed AND lr2.leave_sd)) THEN
		RAISE EXCEPTION 'You are already on leave';
	END IF; 

	-- Adding the newly-applied-for leave into leave_records
	INSERT INTO leave_records VALUES
	(NEW.leave_sd, NEW.leave_ed),
	(CAST(CONCAT(CAST(EXTRACT(YEAR FROM CURRENT_DATE) AS VARCHAR),'-01-01') AS DATE),
		CAST(CONCAT(CAST(EXTRACT(YEAR FROM CURRENT_DATE) AS VARCHAR),'-01-01') AS DATE)),
	(CAST(CONCAT(CAST(EXTRACT(YEAR FROM CURRENT_DATE) AS VARCHAR),'-12-31') AS DATE),
		CAST(CONCAT(CAST(EXTRACT(YEAR FROM CURRENT_DATE) AS VARCHAR),'-12-31') AS DATE));
	
	-- Calculates days between consecutive leaves, including number of days since start of year/to end of year,
	-- and the leave about to be inserted
	CREATE TEMPORARY TABLE days_avail AS
	SELECT LEAD(lr.leave_sd,1) OVER (ORDER BY leave_sd ASC) - lr.leave_ed AS diff
	FROM leave_records lr
	WHERE EXTRACT(YEAR FROM CURRENT_DATE) = EXTRACT(YEAR FROM lr.leave_sd)
	ORDER BY lr.leave_sd ASC;

	-- If the inserted leave results in the constraint of 2x150 days working being unfulfilled, raise exception,
	-- which interrupts the insert
	IF NOT (
		((SELECT COUNT(*) FROM days_avail WHERE diff >= 150) = 2) OR
		((SELECT COUNT(*) FROM days_avail WHERE diff >= 300) = 1)
	) THEN
		RAISE EXCEPTION 'You must work 2x150 days a year';
	END IF; 

	RETURN NEW;
END;
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS enforce_ft_avail ON FT_Leave;

CREATE TRIGGER enforce_ft_avail BEFORE INSERT ON FT_Leave
FOR EACH ROW EXECUTE PROCEDURE trigger_ft_leave_check();