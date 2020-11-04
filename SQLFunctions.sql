-- Page 1
CREATE OR REPLACE FUNCTION login(userid VARCHAR, password VARCHAR)
RETURNS BOOLEAN AS
$func$
BEGIN
	SELECT EXISTS(
		SELECT 1 FROM Accounts
		WHERE username = userid AND password = pw
			);
END;
$func$
LANGUAGE plpgsql;



-- Page 2,3
CREATE OR REPLACE PROCEDURE signup(userid VARCHAR, name VARCHAR, postal INT, address VARCHAR, hp INT, email VARCHAR, pw VARCHAR) AS
$func$ --confirm pw/email to be handled by python
--function run on page 3, data input on pg 2 and 3
BEGIN
	INSERT INTO Accounts VALUES (userid, pw, FALSE)
	INSERT INTO Users VALUES (userid, name, postal, address, hp, email);
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

CREATE OR REPLACE PROCEDURE editPTPetsICanCare(userid VARCHAR, pettype VARCHAR, price FLOAT) AS
$func$ --call different function in python depending on pt/ft
BEGIN
  INSERT INTO PT_validpet VALUES (userid, pettype, price)
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE editFTPetsICanCare(userid VARCHAR, pettype VARCHAR) AS
$func$
BEGIN
  INSERT INTO FT_validpet VALUES (userid, pettype)
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
	INSERT INTO Pet (po_userid, pet_name, birthday, spec_req, pet_type) VALUES (userid, petname, bday, specreq, pettype);
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE editPOpets(userid VARCHAR, petname VARCHAR, bday VARCHAR, specreq VARCHAR, pettype VARCHAR, dieded INTEGER) AS
$func$ --dead = 1 if have change. Need to check if it works, especially if you change name + update dead at same time
-- deletepet will be done by this too. Or should we split?
BEGIN
	UPDATE Pet
	SET pet_name = petname, birthday = bday, spec_req = specreq, pet_type = pettype, dead = (SELECT max(dead)+dieded FROM Pet WHERE po_userid = userid AND pet_name = petname)
	WHERE po_userid = userid, pet_name = petname;
END;
$func$
LANGUAGE plpgsql;

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
CREATE OR REPLACE FUNCTION po_upcoming_bookings(userid VARCHAR)
RETURNS TABLE (petname VARCHAR, ct_userid VARCHAR, start_date DATE, end_date DATE, status VARCHAR) AS
$func$--Do we want to filter for the immediate upcoming 2 weeks, or just ALL upcoming
BEGIN
	SELECT a.pet_name, a.ct_userid, a.start_date, a.end_date, a.status FROM Looking_After a
	WHERE po_userid = userid; 
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION bidsearchuserid (petname VARCHAR, sd DATE, ed DATE)
RETURNS TABLE (userid VARCHAR) AS
$func$
BEGIN
	SELECT ct_userid FROM PT_validpet pt WHERE pt.pet_type IN(
		SELECT pet_type FROM Pet p WHERE p.pet_name = petname)
	UNION
	SELECT ct_userid FROM FT_validpet ft WHERE ft.pet_type IN(
		SELECT pet_type FROM Pet p WHERE p.pet_name = petname)
	EXCEPT
	
	(
	SELECT ct_userid FROM FT_Leave --Remove FT who are unavailable
	WHERE NOT (
		(sd < leave_sd AND ed < leave_sd)
		OR (sd > leave_ed AND sd > leave_ed)
		        )
	)
	INTERSECTION
	(
	SELECT ct_userid FROM PT_Availability
	WHERE sd >= avail_sd AND ed <= avail_ed
	);
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION bidDetails (userid VARCHAR) --Bidsearchuserid and bidDetails are used for page
--6 output. so pg 6 will be sth like bidDetails(bidsearchuserid(petname, sd, ed))
--Todo: fix code when referring to Caretaker_PetPrices. Table was split
RETURNS TABLE (name VARCHAR, avgrating FLOAT, price FLOAT) AS
$func$
BEGIN
	SELECT Users.name AS name, AVG(rating) AS avgrating, ftpt.price AS price
	FROM Users INNER JOIN Looking_After ON Users.userid = Looking_After.ct_userid
		INNER JOIN 
		(
		SELECT ct_userid, pet_type FROM PT_validpet pt
		UNION
		SELECT ct_userid, pet_type FROM FT_validpet ft
		) ftpt ON Users.userid = ftpt.ct_userid
		WHERE ftpt.userid IN userid
	GROUP BY ftpt.userid;
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pastTransactions (userid VARCHAR)
RETURNS TABLE (name VARCHAR, pet_name FLOAT, start_date DATE, end_date DATE) AS
$func$
BEGIN
	SELECT ct.userid AS name, pet_name, start_date, end_date
	FROM Looking_After
	WHERE (po_userid = userid OR ct_userid = userid) AND status = 'Completed';
END;
$func$
LANGUAGE plpgsql;



-- Page 6
CREATE OR REPLACE FUNCTION caretakerReviewRatings (userid VARCHAR)
RETURNS TABLE (review VARCHAR, rating INTEGER) AS
$func$
BEGIN
	SELECT review, rating
	FROM Looking_After
	WHERE ct_userid = userid AND status = 'Completed';
END;
$func$
LANGUAGE plpgsql;


-- Page 8
CREATE OR REPLACE PROCEDURE confirmBooking (pouid VARCHAR, petname VARCHAR, ctuid VARCHAR, sd DATE, ed DATE, price FLOAT, payment_op VARCHAR) AS
$func$
BEGIN
  INSERT INTO Looking_After (po_userid, ct_userid, pet_name, start_date, end_date, trans_pr, payment_op)
  VALUES (pouid, ctuid, petname, sd, ed, price, payment_op);
END;
$func$
LANGUAGE plpgsql;

--Make chat function? sending = update table, receiving = select *



-- Page 9
CREATE OR REPLACE FUNCTION all_your_transac(userid VARCHAR)
RETURNS TABLE (ct_userid VARCHAR, po_userid VARCHAR, pet_name VARCHAR, start_date DATE, end_date DATE, status VARCHAR, rating FLOAT) AS
$func$
BEGIN
	SELECT ct_userid, po_userid, pet_name, start_date, end_date, status, rating FROM Looking_After
	WHERE po_userid = userid OR ct_userid = userid;
END;
$func$
LANGUAGE plpgsql;



-- Page 10
CREATE OR REPLACE FUNCTION ct_reviews(userid VARCHAR)
RETURNS TABLE (ct_userid VARCHAR, po_userid VARCHAR, pet_name VARCHAR, start_date DATE, end_date DATE, status VARCHAR, rating FLOAT, review VARCHAR) AS
$func$
BEGIN
	SELECT ct_userid, po_userid, pet_name, start_date, end_date, status, rating, review FROM Looking_After
	WHERE ct_userid = userid;
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
	SELECT ct_userid, pet_name, start_date, end_date FROM Looking_After
	WHERE ct_userid = userid AND status = 'ACCEPTED';
END;
$func$
LANGUAGE plpgsql;



-- Page 13
CREATE OR REPLACE PROCEDURE ft_applyleave(userid VARCHAR, sd DATE, ed DATE) AS
$func$ --add a check for if FT has taken too much leave, etc
BEGIN
  INSERT INTO FT_Leave VALUES (userid, sd, ed);
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ft_upcomingapprovedleave(userid VARCHAR)
RETURNS TABLE (leave_sd DATE, leave_ed DATE) AS
$func$
BEGIN
	SELECT leave_sd, leave_ed FROM FT_Leave
	WHERE ct_userid = userid;
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE ft_cancelleave(userid VARCHAR, sd DATE, ed DATE) AS
$func$
BEGIN
  
  INSERT INTO FT_Leave VALUES (userid, sd, ed);
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE pt_applyleave(userid VARCHAR, sd DATE, ed DATE) AS
$func$ --add a check for if pT has taken too much leave, etc
BEGIN
  INSERT INTO PT_Availability VALUES (userid, sd, ed);
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pt_upcomingavail(userid VARCHAR)
RETURNS TABLE (avail_sd DATE, avail_ed DATE) AS
$func$
BEGIN
	SELECT avail_sd, avail_ed FROM PT_Availability
	WHERE ct_userid = userid;
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
  SELECT year, month, sum(amount) as salary
  FROM Salary
	WHERE ct_userid = userid
	GROUP BY year ASC, month ASC;
END;
$func$
LANGUAGE plpgsql;



-- Page 15 -- TODO: ADD MORE STUFF HERE, THIS ISNT DONE
CREATE OR REPLACE FUNCTION FT_salary_bd(userid VARCHAR, year INT, month INT)
RETURNS TABLE (pet_name VARCHAR, sd DATE, ed DATE, trans_pr FLOAT) AS
-- Total price for the month to be calculate in python
$func$
BEGIN
  SELECT year, month, sum(amount) as salary
  FROM Salary
	WHERE ct_userid = userid
	GROUP BY year ASC, month ASC;
END;
$func$
LANGUAGE plpgsql;

-- TODO: Add new function to calculate petdays