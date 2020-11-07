CREATE OR REPLACE FUNCTION total_trans_pr_mnth(userid VARCHAR, year INT, month INT)
RETURNS FLOAT4 AS
$func$
DECLARE
	firstday DATE;
	lastday DATE;
BEGIN
	firstday = cast(concat(cast(year AS VARCHAR), '-', cast(month AS VARCHAR),'-01') AS date);
	lastday = cast(concat(cast(year AS VARCHAR), '-', cast((month+1) AS VARCHAR), '-01') AS date);
	
	RETURN 0 + 
		-- Transaction occurs completely in this month
		COALESCE(
		(
			SELECT sum(la.trans_pr)
			FROM Looking_After la
			WHERE userid = la.ct_userid
			AND la.start_date >= firstday AND la.end_date <= lastday
			AND la.status = 'Completed'
		), 0)
		-- Transaction starts before this month, but ends during
		+ COALESCE(
		(
			-- Multiplies trans_pr by no. of days that transaction was in this month
			SELECT sum(lab.trans_pr * (lab.end_date - firstday)/(lab.end_date - lab.start_date))
			FROM Looking_After lab
			WHERE userid = lab.ct_userid
			AND lab.start_date < firstday AND lab.end_date < lastday AND lab.end_date >= firstday
			AND lab.status = 'Completed'
		), 0)
		-- Transaction starts during this month, but ends after
		+ COALESCE(
		(
			-- Multiplies trans_pr by no. of days that transaction was in this month
			SELECT sum(lac.trans_pr * (lastday - lac.start_date)/(lac.end_date - lac.start_date))
			FROM Looking_After lac
			WHERE userid = lac.ct_userid
			AND lac.start_date <= lastday AND lac.start_date >= firstday AND lac.end_date > lastday
			AND lac.status = 'Completed'
		), 0); 
END;
$func$
LANGUAGE plpgsql;
