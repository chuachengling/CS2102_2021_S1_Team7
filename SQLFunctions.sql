-- Page 1
CREATE OR REPLACE FUNCTION login(username VARCHAR, password VARCHAR)
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
	INSERT INTO User VALUES (userid, name, postal, address, hp, email);
END;
$func$
LANGUAGE plpgsql;



-- Page 4
CREATE OR REPLACE PROCEDURE updateProfile(userid VARCHAR, address VARCHAR, postalcode INT, hpnumber INT) AS
$func$
BEGIN
	UPDATE User
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
	INSERT INTO Pet (po.userid, pet_name, birthday, spec_req, pet_type) VALUES (userid, petname, bday, specreq, pettype);
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE editPOpets(userid VARCHAR, petname VARCHAR, bday VARCHAR, specreq VARCHAR, pettype VARCHAR, dieded INTEGER) AS
$func$ --dead = 1 if have change. Need to check if it works, especially if you change name + update dead at same time
-- deletepet will be done by this too. Or should we split?
BEGIN
	UPDATE Pet
	SET pet_name = petname, birthday = bday, spec_req = specreq, pet_type = pettype, dead = (SELECT max(dead)+dieded FROM Pet WHERE po.userid = userid AND pet_name = petname)
	WHERE po.userid = userid, pet_name = petname;
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE editBank(userid VARCHAR, bankacc INT) AS
$func$
BEGIN
  REPLACE INTO Caretaker(ct.userid, bank_acc) VALUES (userid, bankacc)
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE editCredit(userid VARCHAR, credcard INT) AS
$func$
BEGIN
  REPLACE INTO Pet_Owner(po.userid, credit) VALUES (userid, credcard)
END;
$func$
LANGUAGE plpgsql;



-- Page 5
CREATE OR REPLACE FUNCTION ur_current_bookings(userid VARCHAR)
RETURNS TABLE (ct.userid VARCHAR, petname VARCHAR, start_date DATE, end_date DATE, status VARCHAR) AS
$func$
BEGIN
	SELECT ct.userid, pet_name, start_date, end_date, status FROM Looking_After
	WHERE po.userid = userid OR ct.userid = userid;
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION bidsearchuserid (petname VARCHAR, sd DATE, ed DATE)
RETURNS TABLE (userid VARCHAR) AS
$func$
BEGIN
	SELECT ct.userid FROM PT_validpet pt WHERE pt.pet_type IN(
		SELECT pet_type FROM Pet p WHERE p.pet_name = petname)
	UNION
	SELECT ct.userid FROM FT_validpet pt WHERE ft.pet_type IN(
		SELECT pet_type FROM Pet p WHERE p.pet_name = petname)
	EXCEPT

	SELECT ct.userid FROM FT_Leave #Remove FT who are unavailable
	WHERE NOT (
		(sd < leave_sd AND ed < leave_sd)
		OR (sd > leave_ed AND sd > leave_ed)
		)

	)

	INTERSECTION

	(
	SELECT ct.userid FROM PT_Availability
	WHERE sd <= avail_sd AND ed >= avail_ed
	);
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION bidDetails (userid VARCHAR) --Bidsearchuserid and bidDetails are used for page --6 output. so pg 6 will be sth like bidDetails(bidsearchuserid(petname, sd, ed))
--Todo: fix code when referring to Caretaker_PetPrices. Table was split
RETURNS TABLE (name VARCHAR, avgrating FLOAT, price FLOAT) AS
$func$
BEGIN
	SELECT User.name AS name, AVG(rating) AS avgrating, ctpp.price AS price
	FROM User INNER JOIN Looking_After ON User.userid = Looking_After.ct.userid
		INNER JOIN Caretaker_PetPrices ctpp ON User.userid = ctpp.ct.userid
	WHERE ct.userid IN userid
	GROUP BY ct.userid;
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pastTransactions (userid VARCHAR)
RETURNS TABLE (name VARCHAR, pet_name FLOAT, start_date DATE, end_date DATE) AS
$func$
BEGIN
	SELECT ct.userid AS name, pet_name, start_date, end_date
	FROM Looking_After
	WHERE (po.userid = userid OR ct.userid = userid) AND status = 'Completed';
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
	WHERE ct.userid = userid AND status = 'Completed';
END;
$func$
LANGUAGE plpgsql;


-- Page 8
CREATE OR REPLACE PROCEDURE confirmBooking (po.userid VARCHAR, pet_name VARCHAR, ct.userid VARCHAR, sd DATE, ed DATE, price FLOAT, payment_op VARCHAR)
$func$
BEGIN
  INSERT INTO Looking_After (po.userid, ct.userid, pet_name, start_date, end_date, trans_pr, payment_op)
  VALUES (po.userid, ct.userid, pet_name, sd, ed, price, payment_op);
END;
$func$
LANGUAGE plpgsql;

--Make chat function? sending = update table, receiving = select *



-- Page 9
CREATE OR REPLACE FUNCTION all_your_transac(userid VARCHAR)
RETURNS TABLE (ct.userid VARCHAR, po.userid VARCHAR, pet_name VARCHAR, start_date DATE, end_date DATE, status VARCHAR, rating FLOAT) AS
$func$
BEGIN
	SELECT ct.userid, po.userid, pet_name, start_date, end_date, status, rating FROM Looking_After
	WHERE po.userid = userid OR ct.userid = userid;
END;
$func$
LANGUAGE plpgsql;
