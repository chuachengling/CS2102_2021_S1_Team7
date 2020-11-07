CREATE OR REPLACE FUNCTION bid_search (petname VARCHAR, sd DATE, ed DATE)
RETURNS TABLE (userid VARCHAR) AS
$func$
BEGIN
	RETURN QUERY(
		(
			(
				-- PTCT who can care for this pettype
				SELECT pt.ct_userid FROM PT_validpet pt WHERE pt.pet_type IN
					(SELECT p.pet_type FROM Pet p WHERE p.pet_name = bid_search.petname AND p.dead = 0)
			) INTERSECT (
				-- Available PTCT
				SELECT PT_Availability.ct_userid FROM PT_Availability
				WHERE bid_search.sd >= PT_Availability.avail_sd AND bid_search.ed <= PT_Availability.avail_ed
			) EXCEPT (
				-- REMOVE from available PTCT those who are fully booked
				SELECT exp.ctuser FROM explode_date(sd, ed) exp
				GROUP BY exp.ctuser, exp.day
				HAVING COUNT(*) >=
				CASE WHEN (
					SELECT avg(la.rating)
					FROM Looking_After la
					WHERE la.ct_userid = exp.ctuser AND (rating = 'Accepted' OR rating = 'Pending')
				) > 4 THEN 5 
				ELSE 2
				END
			)
		)
		UNION
		(
			-- FTCT who can care for this pettype
			SELECT ft.ct_userid FROM FT_validpet ft WHERE ft.pet_type IN
				(SELECT p.pet_type FROM Pet p WHERE p.pet_name = bid_search.petname AND p.dead = 0)
			EXCEPT (
				-- Remove FT who are unavailable
				SELECT ftl.ct_userid FROM FT_Leave ftl
				WHERE NOT (
					(bid_search.sd < ftl.leave_sd AND bid_search.ed < ftl.leave_sd) OR 
					(bid_search.sd > ftl.leave_ed AND bid_search.sd > ftl.leave_ed)
				)
			) EXCEPT (
				--Remove FT caretakers who have 5 pets at any day in this date range
				SELECT exp2.ctuser FROM explode_date(sd, ed) exp2
				GROUP BY exp2.ctuser, exp2.day
				HAVING COUNT(*) >= 5
			)
		)
	);
END;
$func$
LANGUAGE plpgsql;