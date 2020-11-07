CREATE OR REPLACE FUNCTION total_pet_day_mnth(userid VARCHAR, year INT, month INT)
RETURNS INT AS
$func$
DECLARE
	firstday DATE := CAST(CONCAT(CAST(total_pet_day_mnth.year AS VARCHAR),
		'-', CAST(total_pet_day_mnth.month   AS VARCHAR),'-01') AS DATE);
	lastday DATE  := CAST(CONCAT(CAST(total_pet_day_mnth.year AS VARCHAR),
		'-', CAST(total_pet_day_mnth.month+1 AS VARCHAR),'-01') AS DATE);
BEGIN
	RETURN (
		SELECT GREATEST(
			(
				-- Transaction occurs completely in this month
				SELECT SUM(CAST(EXTRACT(DAY FROM la.end_date) AS INT)
					- CAST(EXTRACT(DAY FROM la.start_date) AS INT) + 1)
				FROM Looking_After la
				WHERE total_pet_day_mnth.userid = la.ct_userid
				AND la.start_date >= firstday AND la.end_date < lastday
				AND la.status = 'Completed'
				GROUP BY la.ct_userid
			), 0)
		+ GREATEST(
			(
				-- Transaction starts before this month, but ends during
				SELECT SUM(CAST(EXTRACT(DAY FROM lab.end_date) AS INT)
					- CAST(EXTRACT(DAY FROM firstday) AS INT) + 1)
				FROM Looking_After lab
				WHERE total_pet_day_mnth.userid = lab.ct_userid
				AND lab.start_date < firstday AND lab.end_date < lastday AND lab.end_date >= firstday
				AND lab.status = 'Completed' 
				GROUP BY lab.ct_userid
			), 0)
		- GREATEST(
			(
				-- Transaction starts during this month, but ends after
				SELECT SUM(CAST(EXTRACT(DAY FROM lastday) AS INT)
					- CAST(EXTRACT(DAY FROM lac.start_date) AS INT) - 1)
				FROM Looking_After lac
				WHERE total_pet_day_mnth.userid = lac.ct_userid
				AND lac.start_date < lastday AND lac.start_date >= firstday AND lac.end_date > lastday
				AND lac.status = 'Completed'
				GROUP BY lac.ct_userid
			), -99999)
	);
END;
$func$
LANGUAGE plpgsql;