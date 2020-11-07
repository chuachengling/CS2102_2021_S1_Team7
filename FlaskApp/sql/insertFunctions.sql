
-- Page 1
CREATE OR REPLACE FUNCTION login(username VARCHAR, pw VARCHAR)
RETURNS BOOLEAN AS
$func$
BEGIN
  RETURN(SELECT EXISTS(
    SELECT 1 FROM Accounts a
    WHERE login.username = a.userid AND login.pw = a.password
      ));
END;
$func$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION user_type(userid VARCHAR)
-- 1: PO
-- 2: CTPT    4: CTFT
-- 3: CTPT+PO  5: CTFT+PO
-- 0: None
RETURNS INTEGER AS
$func$
DECLARE acc_type INTEGER = 0;
BEGIN
  IF (SELECT EXISTS(SELECT 1 FROM Pet_Owner po WHERE po.po_userid = user_type.userid)) THEN acc_type = acc_type + 1;
  END IF; -- +1 if PO
  IF (SELECT EXISTS(SELECT 1 FROM PT_validpet pt WHERE pt.ct_userid = user_type.userid)) THEN acc_type = acc_type + 2;
  END IF; -- +2 if CTPT
  IF (SELECT EXISTS(SELECT 1 FROM FT_validpet ft WHERE ft.ct_userid = user_type.userid)) THEN acc_type = acc_type + 4;
  END IF; -- +4 if CTFT
  RETURN(acc_type);
END;
$func$
LANGUAGE plpgsql;


-- Page 2&3
CREATE OR REPLACE PROCEDURE signup(uid VARCHAR, name VARCHAR, postal INT, address VARCHAR, hp INT, email VARCHAR, pw VARCHAR) AS
$func$ 
--function run on page 3, data input on pg 2 and 3
BEGIN
  INSERT INTO Accounts VALUES (signup.uid, signup.pw)
  ON CONFLICT (userid) DO UPDATE SET deactivate = FALSE, password = pw;
  INSERT INTO Users VALUES (signup.uid, signup.name, signup.postal, signup.address, signup.hp, signup.email)
  ON CONFLICT (userid) DO UPDATE SET name = EXCLUDED.name, postal = EXCLUDED.postal, address = EXCLUDED.address, hp = EXCLUDED.hp, email = EXCLUDED.email;
END;
$func$
LANGUAGE plpgsql;



-- Page 4
CREATE OR REPLACE PROCEDURE updateProfile(userid VARCHAR, address VARCHAR, postalcode INT, hpnumber INT) AS
$func$
BEGIN
  UPDATE Users
  SET postal = updateProfile.postalcode, address = updateProfile.address, hp = updateProfile.hpnumber
  WHERE Users.userid = updateProfile.userid;
END;
$func$
LANGUAGE plpgsql;


CREATE OR REPLACE PROCEDURE editPW(userid VARCHAR, pw VARCHAR) AS
$func$
BEGIN
  UPDATE Accounts 
  SET password = editPW.pw
  WHERE Accounts.userid = editPW.userid;
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE addPTPetsICanCare(userid VARCHAR, pettype VARCHAR, price FLOAT) AS
$func$ --call different function in python depending on pt/ft
BEGIN
  INSERT INTO PT_validpet VALUES (addPTPetsICanCare.userid, addPTPetsICanCare.pettype, addPTPetsICanCare.price);
END;
$func$
LANGUAGE plpgsql;


CREATE OR REPLACE PROCEDURE deletePTPetsICanCare(userid VARCHAR, pettype VARCHAR, price FLOAT) AS
$func$ --call different function in python depending on pt/ft
BEGIN
  DELETE FROM PT_validpet WHERE PT_validpet.ct_userid = deletePTPetsICanCare.userid AND PT_validpet.pet_type = deletePTPetsICanCare.pettype AND PT_validpet.price = deletePTPetsICanCare.price;
END;
$func$
LANGUAGE plpgsql;


CREATE OR REPLACE PROCEDURE addFTPetsICanCare(userid VARCHAR, pettype VARCHAR) AS
$func$ --call different function in python depending on pt/ft
BEGIN
  INSERT INTO FT_validpet VALUES (addFTPetsICanCare.userid, addFTPetsICanCare.pettype);
END;
$func$
LANGUAGE plpgsql;


CREATE OR REPLACE PROCEDURE deleteFTPetsICanCare(userid VARCHAR, pettype VARCHAR) AS
$func$ --call different function in python depending on pt/ft
BEGIN
  DELETE FROM FT_validpet ft WHERE ft.ct_userid = deleteFTPetsICanCare.userid AND ft.pet_type = deleteFTPetsICanCare.pettype;
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE deleteacc(userid VARCHAR) AS
$func$
BEGIN
  UPDATE Accounts
  SET deactivate = TRUE
  WHERE Accounts.userid = deleteacc.userid;
END;
$func$
LANGUAGE plpgsql;


CREATE OR REPLACE PROCEDURE addPOpets(userid VARCHAR, petname VARCHAR, bday DATE, specreq VARCHAR, pettype VARCHAR) AS
$func$
BEGIN
  INSERT INTO Pet VALUES (addPOpets.userid, addPOpets.petname, 0, addPOpets.bday, addPOpets.specreq, addPOpets.pettype);
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE editPOpets(userid VARCHAR, petname VARCHAR, bday DATE, specreq VARCHAR, pettype VARCHAR, dieded INTEGER) AS
$func$ 
-- dead = 1 if have change. Need to check if it works, especially if you change name + update dead at same time
-- dieded value should be 0 or 1. Too lazy to change this to boolean sry
-- deletepet will be done by this too. Or should we split?
BEGIN
  UPDATE Pet
  SET pet_name = petname, birthday = CAST(bday as DATE), spec_req = specreq, pet_type = pettype, dead =
    (SELECT dieded * (max(pa.dead) + dieded) FROM Pet pa WHERE pa.po_userid = userid AND pa.pet_name = petname)
  WHERE po_userid = userid AND pet_name = petname AND dead = 0;
END;
$func$
LANGUAGE plpgsql;


CREATE OR REPLACE PROCEDURE editBank(userid VARCHAR, bankacc CHAR(10)) AS
$func$
BEGIN
  INSERT INTO Caretaker(ct_userid, bank_acc) VALUES (editBank.userid, editBank.bankacc)
  ON CONFLICT (ct_userid) DO UPDATE SET bank_acc = EXCLUDED.bank_acc;
END;
$func$
LANGUAGE plpgsql;


CREATE OR REPLACE PROCEDURE editCredit(userid VARCHAR, credcard CHAR(16)) AS
$func$
BEGIN
  INSERT INTO Pet_Owner(po_userid, credit) VALUES (editCredit.userid, editCredit.credcard)
  ON CONFLICT (po_userid) DO UPDATE SET credit = editCredit.credcard;
END;
$func$
LANGUAGE plpgsql;



-- Page 5
CREATE OR REPLACE FUNCTION po_upcoming_bookings(userid VARCHAR)
RETURNS TABLE (pet_name VARCHAR, ct_userid VARCHAR, start_date DATE, end_date DATE, status VARCHAR) AS
$func$
BEGIN
  RETURN QUERY(
 SELECT b.pet_name,c.name,b.start_date,b.end_date,b.status FROM(
  SELECT a.pet_name, a.ct_userid, a.start_date, a.end_date, a.status FROM Looking_After a
 WHERE a.po_userid = po_upcoming_bookings.userid AND a.status != 'Rejected' AND a.status != 'Completed') AS b
  INNER JOIN 
  (SELECT u.name,u.userid FROM Users u ) AS c ON c.userid = b.ct_userid
  );
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
DECLARE
  runDT DATE;
BEGIN
  runDT = sd;
  CREATE TEMP TABLE exploded_table(ctuser VARCHAR, pouser VARCHAR, petname VARCHAR, dateday DATE) ON COMMIT DROP;
  WHILE runDT <= ed LOOP
    INSERT INTO exploded_table
    SELECT la.ct_userid, la.po_userid, la.pet_name, runDT
    FROM Looking_After la WHERE la.start_date <= runDT AND la.end_date >= runDT;
    runDT := runDT + 1;
  END LOOP;
  RETURN QUERY SELECT * FROM exploded_table;
  DROP TABLE exploded_table;
END;
$func$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION bid_search (petname VARCHAR, sd DATE, ed DATE)
RETURNS TABLE (userid VARCHAR) AS
$func$
BEGIN
  RETURN QUERY(
  ((
  SELECT pt.ct_userid FROM PT_validpet pt WHERE pt.pet_type IN ( -- PTCT who can care for this pettype
    SELECT p.pet_type FROM Pet p WHERE p.pet_name = bid_search.petname)
  )INTERSECT(
  SELECT PT_Availability.ct_userid FROM PT_Availability -- Available PTCT
  WHERE bid_search.sd >= PT_Availability.avail_sd AND bid_search.ed <= PT_Availability.avail_ed
  )EXCEPT(SELECT exp.ctuser FROM explode_date(sd, ed) exp -- REMOVE from available PTCT those who are fully booked
  GROUP BY exp.ctuser, exp.day
  HAVING COUNT(*) >= CASE --define 4 as good rating
                      WHEN (SELECT avg(la.rating) FROM Looking_After la WHERE la.ct_userid = exp.ctuser AND (rating = 'Accepted' OR rating = 'Pending')) > 4 THEN 5
                      ELSE 2
                    END)
  )UNION(
  SELECT ft.ct_userid FROM FT_validpet ft WHERE ft.pet_type IN( --FTCT who can care for this pettype
    SELECT p.pet_type FROM Pet p WHERE p.pet_name = bid_search.petname)
  EXCEPT(SELECT ftl.ct_userid FROM FT_Leave ftl -- Remove FT who are unavailable. Check that this part works, not sure if logic correct
            WHERE NOT ((bid_search.sd < ftl.leave_sd AND bid_search.ed < ftl.leave_sd) OR (bid_search.sd > ftl.leave_ed AND bid_search.sd > ftl.leave_ed)))
  EXCEPT(--Remove FT caretakers who have 5 pets at any day in this date range
  SELECT exp2.ctuser FROM explode_date(sd, ed) exp2
  GROUP BY exp2.ctuser, exp2.day
  HAVING COUNT(*) >= 5
  ))
  )
;
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION bidDetails (userid VARCHAR) 
--Bidsearchuserid and bidDetails are used for page
--6 output. so pg 6 will be sth like bidDetails(bidsearchuserid(petname, sd, ed))
--TODO FIX PRICE!!! Esp for pt
RETURNS TABLE (name VARCHAR, avgrating FLOAT, price FLOAT) AS
$func$
BEGIN
RETURN QUERY(
    SELECT Users.name AS name, AVG(rating) AS avgrating, ftpt.price AS price
    FROM Users INNER JOIN Looking_After ON Users.userid = Looking_After.ct_userid
        INNER JOIN 
        (
        SELECT pt.ct_userid AS ct_userid, pt.pet_type AS pet_type FROM PT_validpet pt
        UNION
        SELECT ft.ct_userid AS ct_userid, ft.pet_type AS pet_type FROM FT_validpet ft
        ) ftpt ON Users.userid = ftpt.ct_userid
    WHERE ftpt.userid = userid
    GROUP BY ftpt.userid
    );
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION pastTransactions (userid VARCHAR)
RETURNS TABLE (name VARCHAR, pet_name VARCHAR, start_date DATE, end_date DATE) AS
$func$
BEGIN
RETURN QUERY(
  SELECT b.pet_name, c.name, b.start_date, b.end_date FROM
 (SELECT  la.pet_name,la.ct_userid , la.start_date, la.end_date
 FROM Looking_After la
 WHERE (la.po_userid = pastTransactions.userid OR la.ct_userid = pastTransactions.userid) AND la.status = 'Completed') AS b
  INNER JOIN 
  (SELECT u.name, u.userid FROM Users u) AS c ON c.userid = b.ct_userid
 );
END;
$func$
LANGUAGE plpgsql;



-- Page 6
--todo create function taking userid, display past ratings n reviews
CREATE OR REPLACE FUNCTION caretakerReviewRatings (userid VARCHAR)
RETURNS TABLE (review VARCHAR, rating FLOAT) AS
$func$
BEGIN
RETURN QUERY(
  SELECT la.review, la.rating
  FROM Looking_After la
  WHERE la.ct_userid = caretakerReviewRatings.userid AND la.status = 'Completed'
  );
END;
$func$
LANGUAGE plpgsql;


-- Page 8
CREATE OR REPLACE PROCEDURE applyBooking (pouid VARCHAR, petname VARCHAR, ctuid VARCHAR, sd DATE, ed DATE, price FLOAT, payment_op VARCHAR) AS
$func$
BEGIN
  INSERT INTO Looking_After (po_userid, ct_userid, pet_name, start_date, end_date, trans_pr, payment_op)
  VALUES (applyBooking.pouid, applyBooking.ctuid, applyBooking.petname, applyBooking.sd, applyBooking.ed, applyBooking.price, applyBooking.payment_op);
END;
$func$
LANGUAGE plpgsql;


-- Page 9
CREATE OR REPLACE FUNCTION all_your_transac(userid VARCHAR)
RETURNS TABLE (ct_userid VARCHAR, po_userid VARCHAR, pet_name VARCHAR, start_date DATE, end_date DATE, status VARCHAR, rating FLOAT) AS
$func$
BEGIN
RETURN QUERY(
    SELECT la.ct_userid, la.po_userid, la.pet_name, la.start_date, la.end_date, la.status, la.rating FROM Looking_After la
    WHERE la.po_userid = all_your_transac.userid OR la.ct_userid = all_your_transac.userid
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
    SELECT la.ct_userid, la.po_userid, la.pet_name, la.start_date, la.end_date, la.status, la.rating, la.review FROM Looking_After la
    WHERE la.ct_userid = ct_reviews.userid AND la.status = 'Completed'
    );
END;
$func$
LANGUAGE plpgsql;



-- Page 11
CREATE OR REPLACE PROCEDURE write_review_rating(userid VARCHAR, pet_name VARCHAR, ct_userid VARCHAR, start_date DATE, end_date DATE, rating INTEGER, review VARCHAR) AS
$func$
BEGIN
  UPDATE Looking_After la
  SET rating=write_review_rating.rating, review=write_review_rating.review
    WHERE la.po_userid = write_review_rating.userid AND la.ct_userid = write_review_rating.ct_userid AND la.start_date = write_review_rating.start_date AND la.end_date = write_review_rating.end_date;
END;
$func$
LANGUAGE plpgsql;



-- Page 12
CREATE OR REPLACE FUNCTION ftpt_upcoming(userid VARCHAR) --ft and pt both use same function. Possible problems if FT becomes PT or vice versa? Or we just assume they can't do that
RETURNS TABLE (petname VARCHAR, name VARCHAR,  start_date DATE, end_date DATE) AS
$func$
BEGIN
RETURN QUERY(
  SELECT b.pet_name, c.name, b.start_date, b.end_date FROM 
  (SELECT la.pet_name, la.po_userid,  la.start_date, la.end_date FROM Looking_After la
  WHERE la.ct_userid = ftpt_upcoming.userid AND la.status = 'Accepted') AS b
  INNER JOIN
  (SELECT u.name,u.userid FROM Users u) AS c ON c.userid = b.po_userid 
  );
END;
$func$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION ftpt_pending(userid VARCHAR) --ft and pt both use same function. Possible problems if FT becomes PT or vice versa? Or we just assume they can't do that
RETURNS TABLE (petname VARCHAR, name VARCHAR,  start_date DATE, end_date DATE) AS
$func$
BEGIN
RETURN QUERY(
  SELECT b.pet_name, c.name, b.start_date, b.end_date FROM 
  (SELECT la.pet_name, la.po_userid,  la.start_date, la.end_date FROM Looking_After la
  WHERE la.ct_userid = ftpt_pending.userid AND la.status = 'Pending') AS b
  INNER JOIN
  (SELECT u.name,u.userid FROM Users u) AS c ON c.userid = b.po_userid 
  );
END;
$func$
LANGUAGE plpgsql;



-- Page 13
CREATE OR REPLACE PROCEDURE ft_applyleave(userid VARCHAR, sd DATE, ed DATE) AS
$func$ --TODO: add a check for if FT has taken too much leave, 
--cannot apply leave if >=1 pet under their care
--search from ft_leave sd to ed, if userid alredy
DECLARE
  involved INTEGER;
BEGIN
  involved = (SELECT COUNT(*) FROM Looking_After la WHERE la.ct_userid = userid and sd between la.start_date and la.end_date or ed between la.start_date and la.end_date);
  IF involved = 0 THEN--condition to check if pet under their care
    INSERT INTO FT_Leave VALUES (ft_applyleave.userid, ft_applyleave.sd, ft_applyleave.ed);
  END IF;
END;
$func$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION ft_upcomingapprovedleave(userid VARCHAR)
RETURNS TABLE (leave_sd DATE, leave_ed DATE) AS
$func$
BEGIN
RETURN QUERY(
    SELECT ftl.leave_sd, ftl.leave_ed FROM FT_Leave ftl
    WHERE ftl.ct_userid = ft_upcomingapprovedleave.userid
    );
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE ft_cancelleave(userid VARCHAR, sd DATE, ed DATE) AS
$func$
BEGIN
  DELETE FROM FT_Leave ft
  WHERE ft.ct_userid = ft_cancelleave.userid AND ft.leave_sd = ft_cancelleave.sd AND ft.leave_ed = ft_cancelleave.ed;
END;
$func$
LANGUAGE plpgsql;


CREATE OR REPLACE PROCEDURE pt_applyavail(userid VARCHAR, sd DATE, ed DATE) AS
$func$ --Checks that PT is applying availability within the next 2 years
BEGIN --CURRENT_DATE is builtin sql function returning current date
  IF EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM pt_applyavail.sd) BETWEEN 0 AND 1 THEN
    INSERT INTO PT_Availability VALUES (pt_applyavail.userid, pt_applyavail.sd, pt_applyavail.ed);
  END IF;
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pt_upcomingavail(userid VARCHAR)
RETURNS TABLE (avail_sd DATE, avail_ed DATE) AS
$func$
BEGIN
RETURN QUERY(
    SELECT pta.avail_sd, pta.avail_ed FROM PT_Availability pta
    WHERE pta.ct_userid = pt_upcomingavail.userid
    );
END;
$func$
LANGUAGE plpgsql;


CREATE OR REPLACE PROCEDURE pt_del_date(userid VARCHAR, sd DATE, ed DATE) AS
$func$ -- No need to check which table user is in, just delete from both pt and ft tables
-- TODO: Maybe delete, this function sucks
DECLARE pt_booked INTEGER;
BEGIN
  pt_booked = (SELECT COUNT(*)
    FROM Looking_After la
    WHERE la.ct_userid = pt_del_date.userid AND pt_del_date.sd <= la.start_date AND pt_del_date.ed >= la.end_date AND la.status = 'Pending');
  
  IF pt_booked = 0 THEN
    DELETE FROM PT_Availability pt WHERE pt.ct_userid = pt_del_date.userid AND pt.avail_sd = pt_del_date.sd AND pt.avail_ed = pt_del_date.ed;
  END IF;
END;
$func$
LANGUAGE plpgsql;

-- Page 14
-- TODO: THIS FUNCTION MAY BE DELETED
CREATE OR REPLACE FUNCTION pastsalary(userid VARCHAR)
RETURNS TABLE (year INT, month INT, salary FLOAT) AS
$func$
BEGIN
RETURN QUERY(
  SELECT s.year, s.month, sum(s.amount) as salary
  FROM Salary s
    WHERE s.ct_userid = ptft_del_date.userid
    GROUP BY s.year, s.month
    );
END;
$func$
LANGUAGE plpgsql;


-- Page 15
CREATE OR REPLACE FUNCTION total_pet_day_mnth(userid VARCHAR, year INT, month INT)
RETURNS INT AS
$func$
DECLARE
  firstday DATE := CAST(CONCAT(CAST(total_pet_day_mnth.year AS VARCHAR), '-', CAST(total_pet_day_mnth.month   AS VARCHAR),'-01') AS DATE);
  lastday DATE  := CAST(CONCAT(CAST(total_pet_day_mnth.year AS VARCHAR), '-', CAST(total_pet_day_mnth.month+1 AS VARCHAR),'-01') AS DATE);
BEGIN
  RETURN (
  SELECT 
  GREATEST((SELECT SUM(CAST(EXTRACT(DAY FROM la.end_date) AS INT) - CAST(EXTRACT(DAY FROM la.start_date) AS INT) + 1)
  FROM Looking_After la
  WHERE total_pet_day_mnth.userid = la.ct_userid
  AND la.start_date >= firstday AND la.end_date < lastday
  AND la.status = 'Completed' --Transaction occurs completely in this month
  GROUP BY la.ct_userid),0)
  +
  GREATEST((SELECT SUM(CAST(EXTRACT(DAY FROM lab.end_date) AS INT) - CAST(EXTRACT(DAY FROM firstday) AS INT) + 1)
  FROM Looking_After lab
  WHERE total_pet_day_mnth.userid = lab.ct_userid
  AND lab.start_date < firstday AND lab.end_date < lastday AND lab.end_date >= firstday
  AND lab.status = 'Completed' --Transaction starts before this month, but ends during
  GROUP BY lab.ct_userid),0)
  - 
  GREATEST((SELECT SUM(CAST(EXTRACT(DAY FROM lastday) AS INT) - CAST(EXTRACT(DAY FROM lac.start_date) AS INT) - 1)
  FROM Looking_After lac
  WHERE total_pet_day_mnth.userid = lac.ct_userid
  AND lac.start_date < lastday AND lac.start_date >= firstday AND lac.end_date > lastday
  AND lac.status = 'Completed' --Transaction starts during this month, but ends after
  GROUP BY lac.ct_userid),-99999)
  );
END;
$func$
LANGUAGE plpgsql;


-- fulltime gets 3k for up to 60 petdays. excess pet days, 80% of price as bonus
-- pt 75% as payment
CREATE OR REPLACE FUNCTION what_salary(userid VARCHAR, dur DATE)
RETURNS FLOAT4 AS
$func$
DECLARE
  earnings FLOAT;
BEGIN
  earnings = total_trans_pr_mnth (userid, EXTRACT(YEAR FROM dur), EXTRACT(MONTH FROM dur));
  IF (SELECT full_time FROM Caretaker ct WHERE ct.ct_userid = userid) THEN
    IF total_pet_day_mnth (userid, EXTRACT(YEAR FROM dur), EXTRACT(MONTH FROM dur)) <= 60 THEN
      RETURN 3000;
    ELSE
      RETURN 3000 + (earnings - 3000) * 0.8;
    END IF;
  ELSE --parttime
    RETURN earnings * 0.75;
  END IF;
END;
$func$
LANGUAGE plpgsql;
  


CREATE OR REPLACE FUNCTION total_trans_pr_mnth(userid VARCHAR, year INT, month INT)
RETURNS FLOAT4 AS
$func$
DECLARE
    firstday DATE;
    lastday DATE;
BEGIN
  firstday = cast(concat(cast(year AS VARCHAR), '-', cast(month AS VARCHAR),'-01') AS date);
  lastday = cast(concat(cast(year AS VARCHAR), '-', cast((month+1) AS VARCHAR), '-01') AS date);
  RETURN 0 + COALESCE((SELECT sum(la.trans_pr)
  FROM Looking_After la
  WHERE userid = la.ct_userid
  AND la.start_date >= firstday AND la.end_date <= lastday
  AND la.status = 'Completed'), 0) --Transaction occurs completely in this month
  +
  COALESCE((SELECT sum(lab.trans_pr * (lab.end_date - firstday)/(lab.end_date - lab.start_date)) -- Multiplies trans_pr by no. of days that transaction was in this month
  FROM Looking_After lab
  WHERE userid = lab.ct_userid
  AND lab.start_date < firstday AND lab.end_date < lastday AND lab.end_date >= firstday
  AND lab.status = 'Completed'), 0) --Transaction starts before this month, but ends during
  +
  COALESCE((SELECT sum(lac.trans_pr * (lastday - lac.start_date)/(lac.end_date - lac.start_date)) -- Multiplies trans_pr by no. of days that transaction was in this month
  FROM Looking_After lac
  WHERE userid = lac.ct_userid
  AND lac.start_date <= lastday AND lac.start_date >= firstday AND lac.end_date > lastday
  AND lac.status = 'Completed'), 0); --Transaction starts during this month, but ends after
END;
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trans_this_month(userid VARCHAR, year INT, month INT)
RETURNS TABLE (po_userid VARCHAR, pet_name VARCHAR, start_date DATE, end_date DATE, rate FLOAT, trans_pr REAL) AS
$func$
DECLARE 
  firstday DATE := CAST(CONCAT(CAST(trans_this_month.year AS VARCHAR), '-', CAST(trans_this_month.month   AS VARCHAR),'-01') AS DATE);
  lastday DATE  := CAST(CONCAT(CAST(trans_this_month.year AS VARCHAR), '-', CAST(trans_this_month.month+1 AS VARCHAR),'-01') AS DATE);
BEGIN
  RETURN QUERY(
  SELECT la.po_userid, la.pet_name, la.start_date, la.end_date, la.trans_pr/(la.end_date - la.start_date + 1) AS rate, la.trans_pr
  FROM Looking_After la
  WHERE la.ct_userid = trans_this_month.userid
  AND NOT (la.start_date < firstday AND la.end_date < firstday)
  AND NOT (la.start_date > lastday AND la.end_date > lastday)
  AND la.status = 'Completed');
END;
$func$
LANGUAGE plpgsql;



-- Page 16
CREATE OR REPLACE FUNCTION petprofile(userid VARCHAR, petname VARCHAR)
RETURNS TABLE (pet_type VARCHAR, birthday DATE, spec_req VARCHAR) AS
$func$
BEGIN
RETURN QUERY(
  SELECT p.pet_type, p.birthday, p.spec_req FROM Pet p
  WHERE p.po_userid = petprofile.userid AND p.pet_name = petprofile.petname AND p.dead = 0
  );
END;
$func$
LANGUAGE plpgsql;

-- MISC
CREATE OR REPLACE PROCEDURE admin_modify_base(pettype VARCHAR, price FLOAT4) AS
$func$
BEGIN
  UPDATE Pet_Type
  SET price = admin_modify_base.price
  WHERE pet_type = admin_modify_base.pettype;
END;
$func$
LANGUAGE plpgsql;

-- TRIGGERS
CREATE OR REPLACE FUNCTION trigger_ft_leave_check()
RETURNS TRIGGER AS
$$ BEGIN
  DROP TABLE IF EXISTS leave_records;
  DROP TABLE IF EXISTS days_avail;
  
  CREATE TEMPORARY TABLE leave_records AS
  (SELECT ftl.leave_sd, ftl.leave_ed FROM FT_Leave ftl WHERE NEW.ct_userid = ftl.ct_userid); -- Has all leave records for the user being inserted

  IF (SELECT EXISTS(SELECT 1 FROM leave_records lr2 WHERE NEW.leave_sd BETWEEN SYMMETRIC lr2.leave_ed AND lr2.leave_sd))
  OR (SELECT EXISTS(SELECT 1 FROM leave_records lr2 WHERE NEW.leave_ed BETWEEN SYMMETRIC lr2.leave_ed AND lr2.leave_sd)) THEN
    RAISE EXCEPTION 'You are already on leave';
  END IF; -- Disallow leave application if caretaker would already be on leave
  
  INSERT INTO leave_records VALUES (NEW.leave_sd, NEW.leave_ed); -- Adding the newly-applied-for leave into leave_records
  
  INSERT INTO leave_records VALUES (CAST(CONCAT(CAST(EXTRACT(YEAR FROM CURRENT_DATE) AS VARCHAR),'-01-01') AS DATE), CAST(CONCAT(CAST(EXTRACT(YEAR FROM CURRENT_DATE) AS VARCHAR),'-01-01') AS DATE));
  INSERT INTO leave_records VALUES (CAST(CONCAT(CAST(EXTRACT(YEAR FROM CURRENT_DATE) AS VARCHAR),'-12-31') AS DATE), CAST(CONCAT(CAST(EXTRACT(YEAR FROM CURRENT_DATE) AS VARCHAR),'-12-31') AS DATE));
  
  
  CREATE TEMPORARY TABLE days_avail AS
  SELECT LEAD(lr.leave_sd,1) OVER (ORDER BY leave_sd ASC) - lr.leave_ed AS diff
  FROM leave_records lr
  WHERE EXTRACT(YEAR FROM CURRENT_DATE) = EXTRACT(YEAR FROM lr.leave_sd)
  ORDER BY lr.leave_sd ASC; -- Calculates days between consecutive leaves, including number of days since start of year/to end of year, and the leave about to be inserted


  IF NOT ( ((SELECT COUNT(*) FROM days_avail WHERE diff >= 150) = 2) OR ((SELECT COUNT(*) FROM days_avail WHERE diff >= 300) = 1) ) THEN
    RAISE EXCEPTION 'You must work 2x150 days a year';
  END IF; -- If the inserted leave results in the constraint of 2x150 days working being unfulfilled, raise exception, which interrupts the insert
  
  RETURN NEW;
END;
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS enforce_ft_avail ON FT_Leave;

CREATE TRIGGER enforce_ft_avail BEFORE INSERT ON FT_Leave
FOR EACH ROW EXECUTE PROCEDURE trigger_ft_leave_check();




CREATE OR REPLACE FUNCTION trigger_price_check()
RETURNS TRIGGER AS
$$ DECLARE
    baseprice FLOAT4;
BEGIN
  baseprice = (SELECT price FROM Pet_Type WHERE pet_type = NEW.pet_type); -- Stores the new prices for each pet type that was updated
  
  UPDATE PT_validpet
  SET price = baseprice
  WHERE (PT_validpet.ct_userid, PT_validpet.pet_type) IN(
  SELECT pt.ct_userid,pt.pet_type FROM PT_validpet pt INNER JOIN Pet_Type base ON pt.pet_type = base.pet_type
  WHERE pt.price < base.price);  -- Increase prices set by Parttime Caretakers if they would fall below this new price

  RETURN NULL;
END;
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS admin_changed_price ON Pet_Type;

CREATE TRIGGER admin_changed_price AFTER UPDATE ON Pet_Type
FOR EACH ROW EXECUTE PROCEDURE trigger_price_check();


CREATE OR REPLACE FUNCTION trigger_pending_check()
RETURNS TRIGGER AS
$$ BEGIN
-- Reject all other pending bids in an overlapping period, if an 'Accepted' status is updated/inserted for a specific pet
  END IF;
  IF NEW.status = 'Accepted' THEN
    UPDATE Looking_After la
    SET status = 'Rejected'
    WHERE la.po_userid = NEW.po_userid AND la.pet_name = NEW.pet_name AND la.status = 'Pending'
    AND NOT (la.start_date < NEW.start_date AND la.end_date < NEW.start_date)
    AND NOT (la.start_date > NEW.end_date AND la.end_date > NEW.end_date);
  RETURN NULL;
END;
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS cancel_pending_bids ON Looking_After;

CREATE TRIGGER cancel_pending_bids AFTER UPDATE OR INSERT ON Looking_After
FOR EACH ROW EXECUTE PROCEDURE trigger_pending_check();