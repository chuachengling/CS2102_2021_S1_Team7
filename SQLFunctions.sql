-- Page 1
CREATE OR REPLACE FUNCTION login(username VARCHAR, pw VARCHAR)
RETURNS BOOLEAN AS
$func$
BEGIN
	RETURN(SELECT EXISTS(
		SELECT 1 FROM Accounts
		WHERE username = userid AND password = pw
			));
END;
$func$
LANGUAGE plpgsql;



-- Page 2,3
CREATE OR REPLACE PROCEDURE signup(userid VARCHAR, name VARCHAR, postal INT, address VARCHAR, hp INT, email VARCHAR, pw VARCHAR) AS
$func$ 
--function run on page 3, data input on pg 2 and 3
BEGIN
  IF (  -- for reactivating their acc
        userid, email, name IN (SELECT userid, email, name FROM Users)
        UPDATE Accounts
        SET deactivate = FALSE
        WHERE userid = userid
  )
  ELSE ( -- completely new acc
        INSERT INTO Accounts VALUES (userid, pw, FALSE)
        INSERT INTO Users VALUES (userid, name, postal, address, hp, email)
  );
END;
$func$
LANGUAGE plpgsql;



-- Page 4
CREATE OR REPLACE PROCEDURE updateProfile(userid VARCHAR, address VARCHAR, postalcode INT, hpnumber INT) AS
$func$
BEGIN
	UPDATE Users
	SET postal = postalcode, address = address, hp = hpnumber
	WHERE userid = userid;
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE editPW(userid VARCHAR, pw VARCHAR) AS
$func$
BEGIN
	UPDATE Accounts
	SET pw = pw
	WHERE userid = userid;
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE addPTPetsICanCare(userid VARCHAR, pettype VARCHAR, price FLOAT) AS
$func$ --call different function in python depending on pt/ft
BEGIN
  INSERT INTO PT_validpet VALUES (userid, pettype, price)
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE deletePTPetsICanCare(userid VARCHAR, pettype VARCHAR, price FLOAT) AS
$func$ --call different function in python depending on pt/ft
BEGIN
  DELETE FROM PT_validpet VALUES ct_userid = userid, pet_type = pettype, price = price)
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE addFTPetsICanCare(userid VARCHAR, pettype VARCHAR) AS
$func$ --call different function in python depending on pt/ft
BEGIN
  INSERT INTO FT_validpet VALUES (userid, pettype)
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE deleteFTPetsICanCare(userid VARCHAR, pettype VARCHAR, price FLOAT) AS
$func$ --call different function in python depending on pt/ft
BEGIN
  DELETE FROM FT_validpet VALUES ct_userid = userid, pet_type = pettype)
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE deleteacc(userid VARCHAR) AS
$func$
BEGIN
  UPDATE Accounts
  SET deactivate = TRUE
  WHERE userid = userid;
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE addPOpets(userid VARCHAR, petname VARCHAR, bday VARCHAR, specreq VARCHAR, pettype VARCHAR) AS
$func$
BEGIN
	INSERT INTO Pet (po_userid, pet_name, dead, birthday, spec_req, pet_type) VALUES (userid, petname, 0, bday, specreq, pettype);
END;
$func$
LANGUAGE plpgsql;

--------- !!!! im not too sure for this - nik
CREATE OR REPLACE PROCEDURE editPOpets(userid VARCHAR, petname VARCHAR, bday VARCHAR, specreq VARCHAR, pettype VARCHAR, dieded INTEGER) AS
$func$ 
-- dead = 1 if have change. Need to check if it works, especially if you change name + update dead at same time
-- dieded value should be 0 or 1. Too lazy to change this to boolean sry
-- deletepet will be done by this too. Or should we split?
BEGIN
	UPDATE Pet
	SET pet_name = petname, birthday = bday, spec_req = specreq, pet_type = pettype, dead = (SELECT max(dead)+dieded FROM Pet WHERE po_userid = userid AND pet_name = petname)
	WHERE po_userid = userid, pet_name = petname;
END;
$func$
LANGUAGE plpgsql;
----------

CREATE OR REPLACE PROCEDURE editBank(userid VARCHAR, bankacc INT) AS
$func$
BEGIN
  REPLACE INTO Caretaker(ct_userid, bank_acc) VALUES (userid, bankacc)
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE editCredit(userid VARCHAR, credcard INT) AS
$func$
BEGIN
  REPLACE INTO Pet_Owner(po_userid, credit) VALUES (userid, credcard)
END;
$func$
LANGUAGE plpgsql;



-- Page 5
-- settled
CREATE OR REPLACE FUNCTION po_upcoming_bookings(userid VARCHAR)
RETURNS TABLE (pet_name VARCHAR, ct_userid VARCHAR, start_date DATE, end_date DATE, status VARCHAR) AS
$func$
BEGIN
  RETURN QUERY(
	SELECT a.pet_name, a.ct_userid, a.start_date, a.end_date, a.status FROM Looking_After a
	WHERE a.po_userid = userid AND a.status != 'Rejected' AND a.status != 'Completed');
END;
$func$
LANGUAGE plpgsql;
--


CREATE OR REPLACE FUNCTION explode_date (sd DATE, ed DATE)
--takes in start date, end date. outputs every single day, with each caretaker booked on that day and what pet they looking after
--get the count of pets by doing groupby day, user.
--for use in bidsearch function when checking # of pets booked for each caretaker
RETURNS TABLE (ctuser VARCHAR, pouser VARCHAR, petname VARCHAR, day DATE) AS
$func$
BEGIN
--DECLARE @minDT DATE, @maxDT Date
--SELECT @minDt =  MIN(start_date) , @,axDt = MAX(end_date) --date range of upcoming accepted pet jobs
--FROM Looking_After WHERE status = 'Accepted'
--delete the above 3 lines if this functions works and doesn't need to be fixed
DECLARE @runDT DATE
SELECT @runDT = sd
DECLARE @exploded_table TABLE(ctuser VARCHAR, pouser VARCHAR, petname VARCHAR, dateday DATE)

WHILE @runDT <= ed
BEGIN
  INSERT INTO @exploded_table (ctuser, pouser, petname, dateday) SELECT la.ct_userid, la.po_userid, la.pet_name, @runDT FROM Looking_After la WHERE la.start_date <= @runDT AND la.end_date >= @runDT
  SET @runDT = @runDT + 1
END
RETURN QUERY(SELECT * FROM @exploded_table);
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION bidsearchuserid (petname VARCHAR, sd DATE, ed DATE)
RETURNS TABLE (userid VARCHAR) AS
$func$
BEGIN

  RETURN QUERY(
  
  (
  
  (
	SELECT ct_userid FROM PT_validpet pt WHERE pt.pet_type IN ( -- PTCT who can care for this pettype
		SELECT pet_type FROM Pet p WHERE p.pet_name = petname)
	)
	INTERSECTION
	(
	SELECT ct_userid FROM PT_Availability -- Available PTCT
	WHERE sd >= avail_sd AND ed <= avail_ed
	)
	
	EXCEPT
	
	(
	SELECT exp.ctuser FROM explode_date(sd, ed) exp -- REMOVE from available PTCT those who are fully booked
	GROUP BY ctuser, day DESC
	HAVING COUNT(*) >= CASE --define 4 as good rating
	                    WHEN (SELECT avg(rating) FROM Looking_After la WHERE la.ct_userid = exp.ctuser) > 4 THEN 5
	                    ELSE 2
	                  END
	)
	
	)
	
	UNION
	
	(
	SELECT ct_userid FROM FT_validpet ft WHERE ft.pet_type IN( --FTCT who can care for this pettype
		SELECT pet_type FROM Pet p WHERE p.pet_name = petname)
	EXCEPT
	(SELECT ct_userid FROM FT_Leave -- Remove FT who are unavailable. Check that this part works, not sure if logic correct
	WHERE NOT (
		(sd < leave_sd AND ed < leave_sd)
		OR (sd > leave_ed AND sd > leave_ed)
	  ))
	  
	EXCEPT --Remove FT caretakers who have 5 pets at any day in this date range
	(
	SELECT ctuser FROM explode_date(sd, ed)
	GROUP BY ctuser, day DESC
	HAVING COUNT(*) = 5
	))
	)
;
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION bidDetails (userid VARCHAR) --Bidsearchuserid and bidDetails are used for page
--6 output. so pg 6 will be sth like bidDetails(bidsearchuserid(petname, sd, ed))
RETURNS TABLE (name VARCHAR, avgrating FLOAT, price FLOAT) AS
$func$
BEGIN
RETURN QUERY(
	SELECT Users.name AS name, AVG(rating) AS avgrating, ftpt.price AS price
	FROM Users INNER JOIN Looking_After ON Users.userid = Looking_After.ct_userid
		INNER JOIN 
		(
		SELECT ct_userid, pet_type FROM PT_validpet pt
		UNION
		SELECT ct_userid, pet_type FROM FT_validpet ft
		) ftpt ON Users.userid = ftpt.ct_userid
		WHERE ftpt.userid IN userid
	GROUP BY ftpt.userid
	);
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pastTransactions (userid VARCHAR)
RETURNS TABLE (name VARCHAR, pet_name FLOAT, start_date DATE, end_date DATE) AS
$func$
BEGIN
RETURN QUERY(
	SELECT ct_userid AS name, pet_name, start_date, end_date
	FROM Looking_After
	WHERE (po_userid = userid OR ct_userid = userid) AND status = 'Completed'
	);
END;
$func$
LANGUAGE plpgsql;



-- Page 6
CREATE OR REPLACE FUNCTION caretakerReviewRatings (userid VARCHAR)
RETURNS TABLE (review VARCHAR, rating INTEGER) AS
$func$
BEGIN
RETURN QUERY(
	SELECT review, rating
	FROM Looking_After
	WHERE ct_userid = userid AND status = 'Completed'
	);
END;
$func$
LANGUAGE plpgsql;


-- Page 8
CREATE OR REPLACE PROCEDURE applyBooking (pouid VARCHAR, petname VARCHAR, ctuid VARCHAR, sd DATE, ed DATE, price FLOAT, payment_op VARCHAR) AS
$func$
BEGIN
  INSERT INTO Looking_After (po_userid, ct_userid, pet_name, start_date, end_date, trans_pr, payment_op)
  VALUES (pouid, ctuid, petname, sd, ed, price, payment_op);
END;
$func$
LANGUAGE plpgsql;


-- Page 9
CREATE OR REPLACE FUNCTION all_your_transac(userid VARCHAR)
RETURNS TABLE (ct_userid VARCHAR, po_userid VARCHAR, pet_name VARCHAR, start_date DATE, end_date DATE, status VARCHAR, rating FLOAT) AS
$func$
BEGIN
RETURN QUERY(
	SELECT ct_userid, po_userid, pet_name, start_date, end_date, status, rating FROM Looking_After
	WHERE po_userid = userid OR ct_userid = userid
	);
END;
$func$
LANGUAGE plpgsql;



-- Page 10
CREATE OR REPLACE FUNCTION ct_reviews(userid VARCHAR)
RETURNS TABLE (ct_userid VARCHAR, po_userid VARCHAR, pet_name VARCHAR, start_date DATE, end_date DATE, status VARCHAR, rating FLOAT, review VARCHAR) AS
$func$
BEGIN
RETURN QUERY(
	SELECT ct_userid, po_userid, pet_name, start_date, end_date, status, rating, review FROM Looking_After
	WHERE ct_userid = userid
	);
END;
$func$
LANGUAGE plpgsql;



-- Page 11
CREATE OR REPLACE PROCEDURE write_review_rating(userid VARCHAR, pet_name VARCHAR, ct_userid VARCHAR, start_date DATE, end_date DATE, rating INTEGER, review VARCHAR) AS
$func$
BEGIN
  UPDATE Looking_After
  SET rating=rating, review=review
	WHERE po_userid = userid AND ct_userid = ct_userid AND start_date = start_date AND end_date = end_date;
END;
$func$
LANGUAGE plpgsql;



-- Page 12
CREATE OR REPLACE FUNCTION ftpt_upcoming(userid VARCHAR) --ft and pt both use same function. Possible problems if FT becomes PT or vice versa? Or we just assume they can't do that
RETURNS TABLE (ct_userid VARCHAR, petname VARCHAR, start_date DATE, end_date DATE) AS
$func$
BEGIN
RETURN QUERY(
	SELECT ct_userid, pet_name, start_date, end_date FROM Looking_After
	WHERE ct_userid = userid AND status = 'ACCEPTED'
	);
END;
$func$
LANGUAGE plpgsql;



-- Page 13
CREATE OR REPLACE PROCEDURE ft_applyleave(userid VARCHAR, sd DATE, ed DATE) AS
$func$ --TODO: add a check for if FT has taken too much leave, 
--cannot apply leave if >=1 pet under their care
BEGIN
  IF --condition to check if pet under their care
    INSERT INTO FT_Leave VALUES (userid, sd, ed);
  END IF;
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ft_upcomingapprovedleave(userid VARCHAR)
RETURNS TABLE (leave_sd DATE, leave_ed DATE) AS
$func$
BEGIN
RETURN QUERY(
	SELECT leave_sd, leave_ed FROM FT_Leave
	WHERE ct_userid = userid
	);
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE ft_cancelleave(userid VARCHAR, sd DATE, ed DATE) AS
$func$
BEGIN
  DELETE FROM FT_Leave ft
  WHERE ft.ct_userid = userid AND ft.avail_sd = sd AND ft.avail_ed = ed ;
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE pt_applyavail(userid VARCHAR, sd DATE, ed DATE) AS
$func$ --Checks that PT is applying availability  within the next 2 years
BEGIN --CURRENT_DATE() is builtin sql function returning current date
  IF EXTRACT(YEAR FROM CURRENT_DATE()) - EXTRACT(YEAR FROM sd) BETWEEN 0 AND 1 THEN
    INSERT INTO PT_Availability VALUES (userid, sd, ed);
  END IF;
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pt_upcomingavail(userid VARCHAR)
RETURNS TABLE (avail_sd DATE, avail_ed DATE) AS
$func$
BEGIN
RETURN QUERY(
	SELECT avail_sd, avail_ed FROM PT_Availability
	WHERE ct_userid = userid
	);
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE ptft_del_date(userid VARCHAR, sd DATE, ed DATE) AS
$func$ -- No need to check which table user is in, just delete from both pt and ft tables
DECLARE @pt_booked BOOLEAN;
BEGIN
  DELETE FROM FT_Leave ft WHERE ft.ct_userid = userid AND ft.leave_sd = sd AND ft.leave_ed = ed;
  
  (
  SELECT CAST(COUNT(*) AS bit) INTO pt_booked -- CAST as boolean value indicating existence of bookings
  FROM Looking_After la
  WHERE la.ct_userid = userid AND sd <= la.start_date AND ed >= la.end_date AND la.status = 'Pending'
  
  IF pt_booked THEN
    DELETE FROM PT_Availability pt WHERE pt.ct_userid = userid AND pt.avail_sd = sd AND pt.avail_ed = ed;
  END IF;
  )
END;
$func$
LANGUAGE plpgsql;

-- Page 14
CREATE OR REPLACE FUNCTION pastsalary(userid VARCHAR)
RETURNS TABLE (year INT, month INT, salary FLOAT) AS
$func$
BEGIN
RETURN QUERY(
  SELECT year, month, sum(amount) as salary
  FROM Salary
	WHERE ct_userid = userid
	GROUP BY year ASC, month ASC
	);
END;
$func$
LANGUAGE plpgsql;



-- Page 15
CREATE OR REPLACE FUNCTION total_trans_pr_mnth(userid VARCHAR, year INT, month INT)
RETURNS FLOAT
$func$
BEGIN
  DECLARE @firstday DATE := cast(cast(year AS VARCHAR) + '-' + cast(month AS VARCHAR) + '-01' AS date)
  DECLARE @lastday DATE := cast(cast(year AS VARCHAR) + '-' + cast((month+1) AS VARCHAR) + '-01' AS date)

  RETURN QUERY(
  (SELECT sum(trans_pr)
  FROM Looking_After la
  WHERE userid = la.ct_userid
  AND (start_date >= firstday AND end_date <= lastday
  AND status = 'Completed') --Transaction occurs completely in this month
  +
  (SELECT sum(trans_pr * (end_date - firstday)/(end_date - start_date)) -- Multiplies trans_pr by no. of days that transaction was in this month
  FROM Looking_After la
  WHERE userid = la.ct_userid
  AND (start_date < firstday AND end_date <= lastday AND end_date >= firstday)
  AND status = 'Completed') --Transaction starts before this month, but ends during
  +
  (SELECT sum(trans_pr * (lastday - start_date)/(end_date - start_date)) -- Multiplies trans_pr by no. of days that transaction was in this month
  FROM Looking_After la
  WHERE userid = la.ct_userid
  AND (start_date <= lastday AND start_date >= firstday AND end_date > lastday)
  AND status = 'Completed') --Transaction starts during this month, but ends after
  +
  (SELECT sum(trans_pr * (lastday - firstday)/(end_date - start_date))
  FROM Looking_After la
  WHERE userid = la.ct_userid
  AND (start_date < firstday AND end_date > lastday
  AND status = 'Completed') --Transaction covers whole month, but starts before and ends after
  ); --TODO: maybe delete if we confirm max transactions 2 weeks
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION total_pet_day_mnth(userid VARCHAR, year INT, month INT)
RETURNS INT
$func$
BEGIN
  DECLARE @firstday DATE := cast(cast(year AS VARCHAR) + '-' + cast(month AS VARCHAR) + '-01' AS date)
  DECLARE @lastday DATE := cast(cast(year AS VARCHAR) + '-' + cast((month+1) AS VARCHAR) + '-01' AS date)

  RETURN QUERY(
  (SELECT sum(EXTRACT(DAY FROM end_date - start_date))
  FROM Looking_After la
  WHERE userid = la.ct_userid
  AND (start_date >= firstday AND end_date <= lastday
  AND status = 'Completed') --Transaction occurs completely in this month
  +
  (SELECT sum(EXTRACT(DAY FROM end_date - firstday))
  FROM Looking_After la
  WHERE userid = la.ct_userid
  AND (start_date < firstday AND end_date <= lastday AND end_date >= firstday)
  AND status = 'Completed') --Transaction starts before this month, but ends during
  +
  (SELECT sum(EXTRACT(DAY FROM lastday - start_date))
  FROM Looking_After la
  WHERE userid = la.ct_userid
  AND (start_date <= lastday AND start_date >= firstday AND end_date > lastday)
  AND status = 'Completed') --Transaction starts during this month, but ends after
  +
  (SELECT sum(lastday - firstday)
  FROM Looking_After la
  WHERE userid = la.ct_userid
  AND (start_date < firstday AND end_date > lastday
  AND status = 'Completed') --Transaction covers whole month, but starts before and ends after
  ); --TODO: maybe delete if we confirm max transactions 2 weeks
END;
$func$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION trans_this_month(userid VARCHAR, year INT, month INT)
RETURNS TABLE (po_userid VARCHAR, pet_name VARCHAR, start_date DATE, end_date DATE, rate FLOAT, trans_pr FLOAT) AS
$func$
BEGIN
  DECLARE @firstday DATE := cast(cast(year AS VARCHAR) + '-' + cast(month AS VARCHAR) + '-01' AS date)
  DECLARE @lastday DATE := cast(cast(year AS VARCHAR) + '-' + cast((month+1) AS VARCHAR) + '-01' AS date)
RETURN QUERY(
  SELECT po_userid, pet_name, start_date, end_date, trans_pr/(end_date-start_date) AS rate, trans_pr
  FROM Looking_After
  WHERE ct_userid = userid
  AND NOT (start_date < firstday AND end_date < firstday)
  AND NOT (start_date > lastday AND end_date > lastday)
  AND status = 'Completed'
  );
END;
$func$
LANGUAGE plpgsql;



-- Page 16
CREATE OR REPLACE FUNCTION petprofile(userid VARCHAR, petname VARCHAR)
RETURNS TABLE (pet_type VARCHAR, birthday DATE, spec_req VARCHAR) AS
$func$
BEGIN
RETURN QUERY(
  SELECT pet_type, birthday, spec_req FROM Pet
  WHERE po_userid = userid AND petname = petname AND dead = 0
  );
END;
$func$
LANGUAGE plpgsql;


-- MISC
CREATE OR REPLACE PROCEDURE admin_modify_base(pet_type VARCHAR, price FLOAT) AS
$func$
BEGIN
  UPDATE Pet_Type
  SET Pet_Type.price = price
  WHERE Pet_Type.pet_type = pet_type;
END;
$func$
LANGUAGE plpgsql;

-- TRIGGERS
CREATE OR REPLACE FUNCTION check_pt_prices() --Raises PT prices, if admin increases base price
RETURNS TRIGGER AS
$$ BEGIN
  UPDATE pt
  SET pt.price = base.price
  FROM PT_validpet pt LEFT JOIN Pet_Type base ON pt.pet_type = base.pet_type
  WHERE pt.price < base.price
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER admin_change_price AFTER UPDATE ON Pet_Type
FOR EACH ROW EXECUTE PROCEDURE check_pt_prices;