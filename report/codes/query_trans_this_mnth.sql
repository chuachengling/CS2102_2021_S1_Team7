CREATE OR REPLACE FUNCTION trans_this_month(userid VARCHAR, year INT, month INT)
RETURNS TABLE (po_userid VARCHAR, pet_name VARCHAR, start_date DATE, end_date DATE, rate FLOAT, trans_pr REAL) AS
$func$
DECLARE 
	firstday DATE := CAST(CONCAT(CAST(trans_this_month.year AS VARCHAR),
		'-', CAST(trans_this_month.month   AS VARCHAR),'-01') AS DATE);
	lastday DATE  := CAST(CONCAT(CAST(trans_this_month.year AS VARCHAR),
		'-', CAST(trans_this_month.month+1 AS VARCHAR),'-01') AS DATE);
BEGIN
	RETURN QUERY(
		SELECT la.po_userid, la.pet_name, la.start_date, la.end_date, la.trans_pr/(la.end_date - la.start_date + 1) AS rate, la.trans_pr
		FROM Looking_After la
		WHERE la.ct_userid = trans_this_month.userid
		AND NOT (la.start_date < firstday AND la.end_date < firstday)
		AND NOT (la.start_date > lastday AND la.end_date > lastday)
		AND la.status = 'Completed'
	);
END;
$func$
LANGUAGE plpgsql;