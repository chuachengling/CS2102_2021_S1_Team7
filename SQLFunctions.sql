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

-- Page2
CREATE OR REPLACE PROCEDURE signup(username VARCHAR, password VARCHAR, email VARCHAR) AS
$func$
BEGIN
	INSERT INTO Accounts (userid, pw) VALUES (username, password)
	INSERT INTO User (userid, email) VALUES (username, email);
END;
$func$
LANGUAGE plpgsql;




-- Page 3

CREATE OR REPLACE PROCEDURE updateProfile(userid VARCHAR, name VARCHAR, address VARCHAR, postalcode INT, hpnumber INT) AS
$func$ --Userid will be taken from previous page, for use as reference. Used for initial setup of profile, and updating profile

BEGIN
	UPDATE User
	SET name = name, postal = postalcode, address = address, hp = hpnumber
	WHERE userid = userid;
END;
$func$
LANGUAGE plpgsql;

-- Page 4
CREATE OR REPLACE PROCEDURE editPW(userid VARCHAR, pw VARCHAR) AS
$func$
BEGIN
	UPDATE Accounts
	SET pw = pw
	WHERE userid = userid;
END;
$func$
LANGUAGE plpgsql;
CREATE OR REPLACE PROCEDURE editPetsICanCare(userid VARCHAR, pettype VARCHAR) AS
$func$ --FIX THIS, DEPENDS ON PARTTIME/FT

BEGIN
	UPDATE Accounts
	SET pw = pw
	WHERE userid = userid;
END;
$func$
LANGUAGE plpgsql;
CREATE OR REPLACE PROCEDURE deleteprofile(userid VARCHAR) AS
$func$
BEGIN
	DELETE FROM Accounts
	WHERE userid = userid;
END;
$func$
LANGUAGE plpgsql;
CREATE OR REPLACE PROCEDURE addPOpets(userid VARCHAR, petname VARCHAR, bday VARCHAR, specreq VARCHAR, pettype VARCHAR) AS
$func$
BEGIN
	INSERT INTO Pet (po.userid, pet_name, birthday, special_requests, pet_type) VALUES (userid, petname, bday, specreq, pettype);
END;
$func$
LANGUAGE plpgsql;
CREATE OR REPLACE PROCEDURE editPOpets(userid VARCHAR, petname VARCHAR, bday VARCHAR, specreq VARCHAR, pettype VARCHAR) AS
$func$
BEGIN
	UPDATE Pet
	SET pet_name = petname, birthday = bday, spec_req = specreq, pet_type = pettype
	WHERE userid = userid, pet_name = petname;
END;
$func$
LANGUAGE plpgsql;
CREATE OR REPLACE PROCEDURE deletepet(userid VARCHAR, petname VARCHAR) AS
$func$
BEGIN
	DELETE FROM Pet
	WHERE po.userid = userid AND pet_name = petname;
END;
$func$
LANGUAGE plpgsql;
CREATE OR REPLACE PROCEDURE editFinances(userid VARCHAR, bankacc INT, credcard INT, specreq VARCHAR, pettype VARCHAR) AS
$func$
BEGIN
	UPDATE Pet
	SET pet_name = petname, birthday = bday, spec_req = specreq, pet_type = pettype
	WHERE userid = userid, pet_name = petname;
END;
$func$
LANGUAGE plpgsql;

















-- Page 5
CREATE OR REPLACE FUNCTION ur_current_bookings(userid VARCHAR)
RETURNS TABLE (ct.userid VARCHAR, avgrating FLOAT, price FLOAT) AS
$func$
BEGIN
	SELECT ct.userid, pet_name, start_date, end_date, status, trans_pr, payment_op FROM Looking_After
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


-- Page 9
CREATE OR REPLACE FUNCTION all_your_transac(userid VARCHAR)
RETURNS TABLE (ct.userid VARCHAR, po.userid VARCHAR, pet_name VARCHAR, start_date DATE, end_date DATE, status VARCHAR, rating FLOAT4) AS
$func$
BEGIN
	SELECT ct.userid, po.userid, pet_name, start_date, end_date, status, rating FROM Looking_After
	WHERE po.userid = userid OR ct.userid = userid;
END;
$func$
LANGUAGE plpgsql;
