-- ADMIN HOMEPAGE --
-- Total number of pets cared for this month, + the breakdown into categories
-- Under/Overperforming FTCT
-- Total revenue/salary this month + salary breakdown
-- Most valuable petowners? output transactions price
CREATE OR REPLACE FUNCTION admin_modify_base(pettype VARCHAR, price FLOAT4)
RETURNS VOID AS
$func$
BEGIN
  UPDATE Pet_Type
  SET price = admin_modify_base.price
  WHERE pet_type = admin_modify_base.pettype;
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION admin_total_num_pets(year INT, month INT)
RETURNS INT AS
$func$
BEGIN
  RETURN(
  SELECT COUNT(DISTINCT(la.po_userid||la.pet_name||la.dead)) FROM Looking_After la
  WHERE la.status = 'Completed' AND
  ((EXTRACT(YEAR FROM la.start_date) = admin_total_num_pets.year AND EXTRACT(MONTH FROM la.start_date) = admin_total_num_pets.month)
  OR (EXTRACT(YEAR FROM la.start_date) = admin_total_num_pets.year AND EXTRACT(MONTH FROM la.start_date) = admin_total_num_pets.month))
  );
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION admin_total_num_pets_bd(year INT, month INT)
RETURNS TABLE(pettype VARCHAR, num BIGINT) AS
$func$
BEGIN
  DROP TABLE IF EXISTS temp_table;
  CREATE TEMPORARY TABLE temp_table AS(
  SELECT la.po_userid, la.pet_name, la.dead FROM Looking_After la
  WHERE la.status = 'Completed' AND
  ((EXTRACT(YEAR FROM la.start_date) = admin_total_num_pets_bd.year AND EXTRACT(MONTH FROM la.start_date) = admin_total_num_pets_bd.month)
  OR (EXTRACT(YEAR FROM la.start_date) = admin_total_num_pets_bd.year AND EXTRACT(MONTH FROM la.start_date) = admin_total_num_pets_bd.month))
  );
  RETURN QUERY(SELECT pet_type, COUNT(DISTINCT(tmp.po_userid||tmp.pet_name||tmp.dead)) FROM temp_table tmp
  LEFT JOIN Pet p
  ON tmp.po_userid = p.po_userid AND tmp.pet_name = p.pet_name AND tmp.dead = p.dead
  GROUP BY pet_type);
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION fire_who(year INT, month INT, rating_threshold FLOAT4, petdays_threshold INTEGER)
RETURNS TABLE(name VARCHAR, ct_userid VARCHAR, avgrating FLOAT4, petdays INTEGER) AS
$func$
BEGIN
  DROP TABLE IF EXISTS working_ftct;
  CREATE TEMPORARY TABLE working_ftct AS(
  SELECT * FROM Looking_After la NATURAL JOIN Caretaker ct
  WHERE ct.full_time AND la.status = 'Completed' AND
  ((EXTRACT(YEAR FROM la.start_date) = fire_who.year AND EXTRACT(MONTH FROM la.start_date) = fire_who.month)
  OR (EXTRACT(YEAR FROM la.start_date) = fire_who.year AND EXTRACT(MONTH FROM la.start_date) = fire_who.month))
  );
   RETURN QUERY(
     SELECT u.name, w.ct_userid, CAST(AVG(w.rating) AS FLOAT4), total_pet_day_mnth(w.ct_userid, fire_who.year, fire_who.month)
     FROM working_ftct w INNER JOIN Users u on w.ct_userid = u.userid
     GROUP BY u.name, w.ct_userid
     HAVING AVG(w.rating) <= fire_who.rating_threshold
     AND total_pet_day_mnth(w.ct_userid, fire_who.year, fire_who.month) <= fire_who.petdays_threshold
     ORDER BY total_pet_day_mnth(w.ct_userid, fire_who.year, fire_who.month) ASC);
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION praise_who(year INT, month INT, rating_threshold FLOAT4, petdays_threshold INTEGER)
RETURNS TABLE(name VARCHAR, ct_userid VARCHAR, avgrating FLOAT4, petdays INTEGER) AS
$func$
BEGIN
  DROP TABLE IF EXISTS working_ftct;
  CREATE TEMPORARY TABLE working_ftct AS(
  SELECT * FROM Looking_After la NATURAL JOIN Caretaker ct
  WHERE ct.full_time AND la.status = 'Completed' AND
  ((EXTRACT(YEAR FROM la.start_date) = praise_who.year AND EXTRACT(MONTH FROM la.start_date) = praise_who.month)
  OR (EXTRACT(YEAR FROM la.start_date) = praise_who.year AND EXTRACT(MONTH FROM la.start_date) = praise_who.month))
  );
   RETURN QUERY(
     SELECT u.name, w.ct_userid, CAST(AVG(w.rating) AS FLOAT4), total_pet_day_mnth(w.ct_userid, praise_who.year, praise_who.month)
     FROM working_ftct w INNER JOIN Users u on w.ct_userid = u.userid
     GROUP BY u.name, w.ct_userid
     HAVING avg(w.rating) >= praise_who.rating_threshold
     AND total_pet_day_mnth(w.ct_userid, praise_who.year, praise_who.month) >= praise_who.petdays_threshold
     ORDER BY total_pet_day_mnth(w.ct_userid, praise_who.year, praise_who.month) DESC);
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION admin_revenue_this_mnth(year INT, month INT)
RETURNS FLOAT8 AS
$func$
DECLARE
    firstday DATE;
    lastday DATE;
BEGIN
  firstday = cast(concat(cast(admin_revenue_this_mnth.year AS VARCHAR), '-', cast(admin_revenue_this_mnth.month AS VARCHAR),'-01') AS date);
  lastday = date_trunc('month', firstday::date) + interval '1 month' - interval '1 day';
  RETURN 0 + COALESCE((SELECT sum(la.trans_pr)
  FROM Looking_After la
  WHERE la.start_date >= firstday AND la.end_date <= lastday
  AND la.status = 'Completed'), 0) --Transaction occurs completely in this month
  +
  COALESCE((SELECT sum(lab.trans_pr * (lab.end_date - firstday + 1)/(lab.end_date - lab.start_date + 1)) -- Multiplies trans_pr by no. of days that transaction was in this month
  FROM Looking_After lab
  WHERE lab.start_date < firstday AND lab.end_date <= lastday AND lab.end_date >= firstday
  AND lab.status = 'Completed'), 0) --Transaction starts before this month, but ends during
  +
  COALESCE((SELECT sum(lac.trans_pr * (lastday - lac.start_date + 1)/(lac.end_date - lac.start_date + 1)) -- Multiplies trans_pr by no. of days that transaction was in this month
  FROM Looking_After lac
  WHERE lac.start_date <= lastday AND lac.start_date >= firstday AND lac.end_date > lastday
  AND lac.status = 'Completed'), 0); --Transaction starts during this month, but ends after
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION admin_salary_payments_this_mnth(year INT, month INT)
RETURNS FLOAT8 AS
$func$
DECLARE
  whatdate DATE := CAST(CAST(admin_salary_payments_this_mnth.year AS VARCHAR)||'-'||CAST(admin_salary_payments_this_mnth.month AS VARCHAR)||'-01' AS DATE);
BEGIN
  RETURN (COALESCE((SELECT SUM(what_salary(working_ftct.ct_userid,whatdate)) FROM
  (SELECT DISTINCT(la.ct_userid) FROM Looking_After la
  WHERE la.status = 'Completed' AND
  ((EXTRACT(YEAR FROM la.start_date) = admin_salary_payments_this_mnth.year AND EXTRACT(MONTH FROM la.start_date) = admin_salary_payments_this_mnth.month)
  OR (EXTRACT(YEAR FROM la.start_date) = admin_salary_payments_this_mnth.year AND EXTRACT(MONTH FROM la.start_date) = admin_salary_payments_this_mnth.month))
  ) working_ftct ),0));
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION admin_salary_payments_this_mnth_bd(year INT, month INT)
RETURNS TABLE(userid VARCHAR, salary FLOAT4) AS
$func$
DECLARE
  whatdate DATE := CAST(CAST(admin_salary_payments_this_mnth_bd.year AS VARCHAR)||'-'||CAST(admin_salary_payments_this_mnth_bd.month AS VARCHAR)||'-01' AS DATE);
BEGIN
  RETURN QUERY(SELECT working_ftct.ct_userid, what_salary(working_ftct.ct_userid,whatdate) FROM
  (SELECT DISTINCT(la.ct_userid) FROM Looking_After la
  WHERE la.status = 'Completed' AND
  ((EXTRACT(YEAR FROM la.start_date) = admin_salary_payments_this_mnth_bd.year AND EXTRACT(MONTH FROM la.start_date) = admin_salary_payments_this_mnth_bd.month)
  OR (EXTRACT(YEAR FROM la.start_date) = admin_salary_payments_this_mnth_bd.year AND EXTRACT(MONTH FROM la.start_date) = admin_salary_payments_this_mnth_bd.month))
  ) working_ftct);
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION admin_valuable_po(year INT, month INT)
RETURNS TABLE(po_userid VARCHAR, payments FLOAT) AS
$func$
DECLARE
    firstday DATE;
    lastday DATE;
BEGIN
  firstday = cast(concat(cast(admin_valuable_po.year AS VARCHAR), '-', cast(admin_valuable_po.month AS VARCHAR),'-01') AS date);
  lastday = date_trunc('month', firstday::date) + interval '1 month' - interval '1 day';
RETURN QUERY(SELECT combined.po_userid, SUM(combined.trans_pr) FROM
  ((SELECT la.po_userid, la.trans_pr
  FROM Looking_After la
  WHERE la.start_date >= firstday AND la.end_date <= lastday
  AND la.status = 'Completed') --Transaction occurs completely in this month
  UNION
  (SELECT lab.po_userid, lab.trans_pr * (lab.end_date - firstday + 1)/(lab.end_date - lab.start_date + 1)
  FROM Looking_After lab
  WHERE lab.start_date < firstday AND lab.end_date <= lastday AND lab.end_date >= firstday
  AND lab.status = 'Completed') --Transaction starts before this month, but ends during
  UNION
  (SELECT lac.po_userid, lac.trans_pr * (lastday - lac.start_date + 1)/(lac.end_date - lac.start_date + 1)
  FROM Looking_After lac
  WHERE lac.start_date <= lastday AND lac.start_date >= firstday AND lac.end_date > lastday
  AND lac.status = 'Completed')) combined
  GROUP BY combined.po_userid
  ORDER BY SUM(combined.trans_pr) DESC
  LIMIT 10
  ); --Transaction starts during this month, but ends after
END;
$func$
LANGUAGE plpgsql;



-- Page 1
CREATE OR REPLACE FUNCTION login(username VARCHAR, pw VARCHAR)
RETURNS BOOLEAN AS
$func$
BEGIN
--Mark transaction as completed if end date is over
  UPDATE Looking_After la
  SET status = 'Completed'
  WHERE la.status = 'Accepted' AND la.end_date > CURRENT_DATE;
  RETURN(SELECT EXISTS(
    SELECT 1 FROM Accounts a
    WHERE login.username = a.userid AND login.pw = a.password));
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
  IF EXISTS(SELECT 1 FROM Pet_Owner po WHERE po.po_userid = user_type.userid) THEN acc_type = acc_type + 1;
  END IF; -- +1 if PO
  IF EXISTS(SELECT 1 FROM Caretaker ct WHERE ct.ct_userid = user_type.userid) THEN
    IF full_time FROM Caretaker ct2 WHERE ct2.ct_userid = user_type.userid THEN acc_type = acc_Type + 4;
    ELSE
    acc_type = acc_type + 2;
    END IF;
  END IF;
  -- IF EXISTS(SELECT 1 FROM PT_validpet pt WHERE pt.ct_userid = user_type.userid) THEN acc_type = acc_type + 2;
  -- END IF; -- +2 if CTPT
  -- IF EXISTS(SELECT 1 FROM FT_validpet ft WHERE ft.ct_userid = user_type.userid) THEN acc_type = acc_type + 4;
  -- END IF; -- +4 if CTFT
  RETURN(acc_type);
END;
$func$
LANGUAGE plpgsql;



-- Page 2&3
CREATE OR REPLACE FUNCTION signup(uid VARCHAR, name VARCHAR, postal INT, address VARCHAR, hp INT, email VARCHAR, pw VARCHAR)
RETURNS VOID AS
$func$ 
BEGIN
  IF EXISTS(SELECT 1 FROM Accounts a WHERE signup.uid=a.userid) THEN
    IF EXISTS(SELECT 1 FROM Accounts a1 WHERE signup.uid = a1.userid AND signup.pw = a1.password AND deactivate) THEN
      UPDATE Accounts
      SET deactivate = FALSE
      WHERE userid = uid;
    END IF;
  ELSE
    INSERT INTO Accounts VALUES (signup.uid, signup.pw);
    INSERT INTO Users VALUES (signup.uid, signup.name, signup.postal, signup.address, signup.hp, signup.email);
  END IF;
END;
$func$
LANGUAGE plpgsql;



-- Page 4
CREATE OR REPLACE FUNCTION all_POpets_deets(userid VARCHAR) 
RETURNS TABLE(pn VARCHAR, pt VARCHAR, dob DATE, sp VARCHAR ) AS
$func$
BEGIN
  RETURN QUERY(
  SELECT pet_name, pet_type, birthday, spec_req FROM Pet WHERE po_userid = userid AND dead = 0
  );
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION updateProfile(userid VARCHAR, address VARCHAR, postalcode INT, hpnumber INT)
RETURNS VOID AS
$func$
BEGIN
  UPDATE Users
  SET postal = updateProfile.postalcode, address = updateProfile.address, hp = updateProfile.hpnumber
  WHERE Users.userid = updateProfile.userid;
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION editPW(userid VARCHAR, pw VARCHAR)
RETURNS VOID AS
$func$
BEGIN
  UPDATE Accounts 
  SET password = editPW.pw
  WHERE Accounts.userid = editPW.userid;
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION addPTPetsICanCare(userid VARCHAR, pettype VARCHAR, price FLOAT)
RETURNS VOID AS
$func$ --call different function in python depending on pt/ft
BEGIN
  INSERT INTO PT_validpet VALUES (addPTPetsICanCare.userid, addPTPetsICanCare.pettype, addPTPetsICanCare.price);
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION deletePTPetsICanCare(userid VARCHAR, pettype VARCHAR)
RETURNS VOID AS
$func$ --call different function in python depending on pt/ft
BEGIN
  DELETE FROM PT_validpet WHERE PT_validpet.ct_userid = deletePTPetsICanCare.userid AND PT_validpet.pet_type = deletePTPetsICanCare.pettype;
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION addFTPetsICanCare(userid VARCHAR, pettype VARCHAR)
RETURNS VOID AS
$func$ --call different function in python depending on pt/ft
BEGIN
  INSERT INTO FT_validpet VALUES (addFTPetsICanCare.userid, addFTPetsICanCare.pettype);
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION deleteFTPetsICanCare(userid VARCHAR, pettype VARCHAR)
RETURNS VOID AS
$func$ --call different function in python depending on pt/ft
BEGIN
  DELETE FROM FT_validpet ft WHERE ft.ct_userid = deleteFTPetsICanCare.userid AND ft.pet_type = deleteFTPetsICanCare.pettype;
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION deleteacc(userid VARCHAR)
RETURNS VOID AS
$func$
BEGIN
  UPDATE Accounts
  SET deactivate = TRUE
  WHERE Accounts.userid = deleteacc.userid;
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION addPOpets(userid VARCHAR, petname VARCHAR, bday DATE, specreq VARCHAR, pettype VARCHAR)
RETURNS VOID AS
$func$
BEGIN
  INSERT INTO Pet VALUES (addPOpets.userid, addPOpets.petname, 0, addPOpets.bday, addPOpets.specreq, addPOpets.pettype);
END;
$func$
LANGUAGE plpgsql;



-- OLD FUNCTION, REPLACED BY removePOpet
-- CREATE OR REPLACE FUNCTION editPOpets(userid VARCHAR, petname VARCHAR, bday DATE, specreq VARCHAR, pettype VARCHAR, dieded INTEGER)
-- RETURNS VOID AS
-- $func$ 
-- -- petname cannot be changed
-- BEGIN
--   UPDATE Pet
--   SET birthday = bday, spec_req = specreq, pet_type = pettype, dead =
--     (SELECT dieded * (max(pa.dead) + dieded) FROM Pet pa WHERE pa.po_userid = userid AND pa.pet_name = petname)
--   WHERE po_userid = userid AND pet_name = petname AND dead = 0;
-- END;
-- $func$
-- LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION removePOpet(pouserid VARCHAR, petname VARCHAR)
RETURNS VOID AS
$func$
BEGIN
  UPDATE Pet p
  SET dead = max(pa.dead) + 1
  WHERE p.po_userid = pouserid AND p.pet_name = petname;
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION editBank(userid VARCHAR, bankacc CHAR(10))
RETURNS VOID AS
$func$
BEGIN
  INSERT INTO Caretaker(ct_userid, bank_acc) VALUES (editBank.userid, editBank.bankacc)
  ON CONFLICT (ct_userid) DO UPDATE SET bank_acc = EXCLUDED.bank_acc;
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION editCredit(userid VARCHAR, credcard CHAR(16))
RETURNS VOID AS
$func$
BEGIN
  INSERT INTO Pet_Owner(po_userid, credit) VALUES (editCredit.userid, editCredit.credcard)
  ON CONFLICT (po_userid) DO UPDATE SET credit = editCredit.credcard;
END;
$func$
LANGUAGE plpgsql;



-- Page 5
CREATE OR REPLACE FUNCTION find_hp(userid VARCHAR)
RETURNS INTEGER AS
$func$
BEGIN
  RETURN(SELECT u.hp FROM Users u WHERE u.userid = find_hp.userid);
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION find_pets(userid VARCHAR)
RETURNS TABLE (pet_name VARCHAR) AS
$func$
BEGIN
  RETURN QUERY(SELECT p.pet_name FROM Pet p WHERE p.po_userid = find_pets.userid AND p.dead = 0);
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION po_upcoming_bookings(userid VARCHAR)
RETURNS TABLE (pet_name VARCHAR, ct_userid VARCHAR, start_date DATE, end_date DATE, status VARCHAR,dead INTEGER) AS
$func$
BEGIN
  RETURN QUERY(
 SELECT b.pet_name,c.name,b.start_date,b.end_date,b.status,b.dead FROM(
  SELECT a.pet_name, a.ct_userid, a.start_date, a.end_date, a.status, a.dead FROM Looking_After a
 WHERE a.po_userid = po_upcoming_bookings.userid AND a.status != 'Rejected' AND a.status != 'Completed') AS b
  INNER JOIN 
  (SELECT u.name,u.userid FROM Users u ) AS c ON c.userid = b.ct_userid
  );
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION explode_date (sd DATE, ed DATE)
--takes in start date, end date. outputs every single day, with each caretaker booked on that day and what pet they looking after
--get the count of pets by doing groupby day, user.
--for use in bid_search function when checking # of pets booked for each caretaker
RETURNS TABLE (ctuser VARCHAR, pouser VARCHAR, petname VARCHAR, day DATE) AS
$func$
DECLARE
  runDT DATE;
BEGIN
  DROP TABLE IF EXISTS exploded_table;
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

-- find_pettype(po_userid, petname, 0)
CREATE OR REPLACE FUNCTION bid_search (po_userid VARCHAR, petname VARCHAR, sd DATE, ed DATE)
RETURNS TABLE (userid VARCHAR) AS
$func$
BEGIN
  RETURN QUERY(
  ((
  SELECT pt.ct_userid FROM PT_validpet pt WHERE pt.pet_type = find_pettype(bid_search.po_userid,bid_search.petname,0)
  )INTERSECT(
  SELECT PT_Availability.ct_userid FROM PT_Availability -- Check for available PTCT
  WHERE bid_search.sd >= PT_Availability.avail_sd AND bid_search.ed <= PT_Availability.avail_ed
  )
  EXCEPT(SELECT exp.ctuser FROM explode_date(sd, ed) exp -- REMOVE PTCT who are fully booked
  GROUP BY exp.ctuser, exp.day
  HAVING COUNT(*) >= CASE -- Using >=4 as good rating
                      WHEN find_avg_rating(exp.ctuser) >= 4 THEN 5
                      ELSE 2
                    END)
  )
  UNION(
  SELECT ft.ct_userid FROM FT_validpet ft WHERE ft.pet_type = find_pettype(bid_search.po_userid,bid_search.petname,0)
  EXCEPT(SELECT ftl.ct_userid FROM FT_Leave ftl WHERE (bid_search.sd BETWEEN ftl.leave_sd AND ftl.leave_ed) OR (bid_search.ed BETWEEN ftl.leave_sd AND ftl.leave_ed))
  EXCEPT(--Remove FT caretakers who have >=5 pets at any day in this date range
  SELECT exp2.ctuser FROM explode_date(sd, ed) exp2
  GROUP BY exp2.ctuser, exp2.day
  HAVING COUNT(*) >= 5
  ))
  );
END;
$func$
LANGUAGE plpgsql;
-- CREATE OR REPLACE FUNCTION bid_search (petname VARCHAR, sd DATE, ed DATE)
-- RETURNS TABLE (userid VARCHAR) AS
-- $func$
-- BEGIN
--   RETURN QUERY(
--   ((
--   SELECT pt.ct_userid FROM PT_validpet pt WHERE pt.pet_type IN ( -- PTCT who can care for this pettype
--     SELECT p.pet_type FROM Pet p WHERE p.pet_name = bid_search.petname AND p.dead = 0)
--   )INTERSECT(
--   SELECT PT_Availability.ct_userid FROM PT_Availability -- Check for available PTCT
--   WHERE bid_search.sd >= PT_Availability.avail_sd AND bid_search.ed <= PT_Availability.avail_ed
--   )EXCEPT(SELECT exp.ctuser FROM explode_date(sd, ed) exp -- REMOVE PTCT who are fully booked
--   GROUP BY exp.ctuser, exp.day
--   HAVING COUNT(*) >= CASE -- Using >=4 as good rating
--                       WHEN (SELECT avg(la.rating) FROM Looking_After la WHERE la.ct_userid = exp.ctuser AND (status = 'Accepted' OR status = 'Pending')) >= 4 THEN 5
--                       ELSE 2
--                     END)
--   )UNION(
--   SELECT ft.ct_userid FROM FT_validpet ft WHERE ft.pet_type IN( --FTCT who can care for this pettype
--     SELECT p.pet_type FROM Pet p WHERE p.pet_name = bid_search.petname AND p.dead = 0)
--   EXCEPT(SELECT ftl.ct_userid FROM FT_Leave ftl -- Remove FT who are unavailable. Check that this part works, not sure if logic correct
--             WHERE NOT ((bid_search.sd < ftl.leave_sd AND bid_search.ed < ftl.leave_sd) OR (bid_search.sd > ftl.leave_ed AND bid_search.sd > ftl.leave_ed)))
--   EXCEPT(--Remove FT caretakers who have >=5 pets at any day in this date range
--   SELECT exp2.ctuser FROM explode_date(sd, ed) exp2
--   GROUP BY exp2.ctuser, exp2.day
--   HAVING COUNT(*) >= 5
--   ))
--   );
-- END;
-- $func$
-- LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION bidDetails (ctuserid VARCHAR, pouserid VARCHAR, petname VARCHAR) 
RETURNS TABLE (name VARCHAR, avgrating FLOAT4, price FLOAT4) AS
$func$
BEGIN
  RETURN QUERY(SELECT find_name(ctuserid), find_avg_rating(ctuserid), find_rate(ctuserid, find_pettype(bidDetails.pouserid, bidDetails.petname, 0)));
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION find_avg_rating (ctuserid VARCHAR)
RETURNS FLOAT4 AS
$func$
BEGIN
  RETURN(SELECT AVG(la.rating) FROM Looking_After la
  WHERE la.ct_userid = find_avg_rating.ctuserid AND la.status = 'Completed');
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION pastTransactions (userid VARCHAR)
RETURNS TABLE (po_name VARCHAR, ct_name VARCHAR, pet_name VARCHAR, dead INTEGER, start_date DATE, end_date DATE) AS
$func$
BEGIN
RETURN QUERY(
 SELECT (SELECT u.name FROM Users u WHERE u.userid = la.po_userid) AS po_name, (SELECT u.name FROM Users u WHERE u.userid = la.ct_userid) AS ct_name, la.pet_name, la.dead, la.start_date, la.end_date
 FROM Looking_After la
 WHERE (la.po_userid = pastTransactions.userid OR la.ct_userid = pastTransactions.userid) AND la.status = 'Completed');
END;
$func$
LANGUAGE plpgsql;



-- Page 6
CREATE OR REPLACE FUNCTION caretakerReviewRatings (userid VARCHAR)
RETURNS TABLE (review VARCHAR, rating FLOAT4) AS
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



-- Page 7
CREATE OR REPLACE FUNCTION find_pettype(userid VARCHAR, petname VARCHAR, dead INTEGER)
RETURNS VARCHAR AS
$func$
BEGIN
  RETURN (SELECT p.pet_type FROM Pet p WHERE p.po_userid = userid AND p.pet_name = petname AND find_pettype.dead = p.dead);
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION find_name(userid VARCHAR)
RETURNS VARCHAR AS
$func$
BEGIN
  RETURN (SELECT u.name FROM Users u WHERE u.userid = find_name.userid);
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION find_specreq(userid VARCHAR, petname VARCHAR, dead INTEGER)
RETURNS VARCHAR AS
$func$
BEGIN
  RETURN (SELECT p.spec_req FROM Pet p WHERE p.po_userid = find_specreq.userid AND p.pet_name = find_specreq.petname AND find_specreq.dead = p.dead);
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION find_rate(query_userid VARCHAR, pettype VARCHAR)
RETURNS FLOAT4 AS
$func$
BEGIN
  IF (SELECT ct.full_time FROM Caretaker ct WHERE ct.ct_userid = query_userid) THEN
    RETURN (SELECT ptype.price FROM Pet_Type ptype WHERE ptype.pet_type = pettype);
  ELSE
    RETURN (SELECT ptvp.price FROM PT_validpet ptvp WHERE ptvp.ct_userid = query_userid AND ptvp.pet_type = pettype);
  END IF;
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION find_card(userid VARCHAR)
RETURNS CHAR AS
$func$
BEGIN
  RETURN (COALESCE((SELECT po.credit FROM Pet_Owner po WHERE po.po_userid = find_card.userid), '0'));
END;
$func$
LANGUAGE plpgsql;



-- Page 8
CREATE OR REPLACE FUNCTION what_caretaker(po_userid VARCHAR, petname VARCHAR, sd DATE, ed DATE)
RETURNS VARCHAR AS
$func$
BEGIN
  SELECT la.ct_userid FROM Looking_After la WHERE la.po_userid = what_caretaker.po_userid AND la.pet_name = what_caretaker.petname AND la.start_date = what_caretaker.sd AND la.end_date = what_caretaker.ed;
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION what_trans_pr(ct_userid VARCHAR, po_userid VARCHAR, pet_name VARCHAR, dead INTEGER, sd DATE, ed DATE)
RETURNS FLOAT4 AS
$func$
BEGIN
  RETURN((sd-ed+1)*find_rate(what_trans_pr.ct_userid, find_pettype(what_trans_pr.po_userid, what_trans_pr.pet_name, what_trans_pr.dead)));
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION applyBooking (pouid VARCHAR, petname VARCHAR, dead INTEGER, ctuid VARCHAR, sd DATE, ed DATE, payment_op VARCHAR)
RETURNS VOID AS
$func$
DECLARE
  price FLOAT4;
BEGIN
  price := what_trans_pr(applyBooking.ctuid, applyBooking.pouid, applyBooking.petname, applyBooking.dead, applyBooking.sd, applyBooking.ed);
  
  IF (SELECT ct.full_time FROM Caretaker ct WHERE ct.ct_userid = applyBooking.ctuid) THEN
    INSERT INTO Looking_After (po_userid, ct_userid, pet_name, dead, start_date, end_date, status, trans_pr, payment_op)
    VALUES (applyBooking.pouid, applyBooking.ctuid, applyBooking.petname, applyBooking.dead, applyBooking.sd, applyBooking.ed, 'Accepted', price, applyBooking.payment_op);
  ELSE
    INSERT INTO Looking_After (po_userid, ct_userid, pet_name, dead, start_date, end_date, status, trans_pr, payment_op)
    VALUES (applyBooking.pouid, applyBooking.ctuid, applyBooking.petname, applyBooking.dead, applyBooking.sd, applyBooking.ed, 'Pending', price, applyBooking.payment_op);
  END IF;
END;
$func$
LANGUAGE plpgsql;


-- Page 9
CREATE OR REPLACE FUNCTION all_your_transac(userid VARCHAR)
RETURNS TABLE (ct_userid VARCHAR, po_userid VARCHAR, pet_name VARCHAR, dead INTEGER, start_date DATE, end_date DATE, status VARCHAR, rating FLOAT8) AS
$func$
BEGIN
RETURN QUERY(
    SELECT la.ct_userid, la.po_userid, la.pet_name, la.dead, la.start_date, la.end_date, la.status, la.rating FROM Looking_After la
    WHERE la.po_userid = all_your_transac.userid OR la.ct_userid = all_your_transac.userid
    );
END;
$func$
LANGUAGE plpgsql;



-- Page 10
CREATE OR REPLACE FUNCTION ct_reviews(userid VARCHAR)
RETURNS TABLE (ct_userid VARCHAR, po_userid VARCHAR, pet_name VARCHAR, start_date DATE, end_date DATE, status VARCHAR, rating FLOAT4, review VARCHAR) AS
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
CREATE OR REPLACE FUNCTION write_review_rating(po_userid VARCHAR, pet_name VARCHAR, dead INTEGER, ct_userid VARCHAR, start_date DATE, end_date DATE, rating FLOAT4, review VARCHAR)
RETURNS VOID AS
$func$
BEGIN
  UPDATE Looking_After la
  SET rating=write_review_rating.rating, review=write_review_rating.review
  WHERE la.po_userid = write_review_rating.po_userid AND la.ct_userid = write_review_rating.ct_userid AND la.pet_name = write_review_rating.pet_name AND la.dead = write_review_rating.dead AND la.start_date = write_review_rating.start_date AND la.end_date = write_review_rating.end_date;
END;
$func$
LANGUAGE plpgsql;



-- Page 12
CREATE OR REPLACE FUNCTION ftpt_upcoming(userid VARCHAR)
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



CREATE OR REPLACE FUNCTION ftpt_pending(userid VARCHAR)
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
CREATE OR REPLACE FUNCTION ft_applyleave(userid VARCHAR, sd DATE, ed DATE)
RETURNS VOID AS
$func$
DECLARE
  involved INTEGER;
BEGIN
  involved = (SELECT COUNT(*) FROM Looking_After la WHERE la.ct_userid = userid AND ((sd BETWEEN la.start_date AND la.end_date) OR (ed BETWEEN la.start_date AND la.end_date)));
  IF involved = 0 THEN -- Condition to check if no pet under their care
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
    AND CURRENT_DATE <= ftl.leave_sd
    );
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION ft_cancelleave(userid VARCHAR, sd DATE, ed DATE)
RETURNS VOID AS
$func$
BEGIN
  DELETE FROM FT_Leave ft
  WHERE ft.ct_userid = ft_cancelleave.userid AND ft.leave_sd = ft_cancelleave.sd AND ft.leave_ed = ft_cancelleave.ed;
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION pt_applyavail(userid VARCHAR, sd DATE, ed DATE)
RETURNS VOID AS
$func$ --Checks that PT is applying availability within the next 2 years
BEGIN
  IF (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM pt_applyavail.sd)) BETWEEN 0 AND 1 THEN
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
    AND CURRENT_DATE <= pta.avail_sd
    );
END;
$func$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION pt_del_date(userid VARCHAR, sd DATE, ed DATE)
RETURNS VOID AS
$func$ -- For PTCT to cancel availability
DECLARE pt_booked INTEGER;
BEGIN
  pt_booked = (SELECT COUNT(*)
    FROM Looking_After la
    WHERE la.ct_userid = pt_del_date.userid AND (la.status = 'Pending' OR la.status = 'Accepted') AND NOT (pt_del_date.ed <= la.start_date OR pt_del_date.sd >= la.end_date) );
  IF pt_booked = 0 THEN
    DELETE FROM PT_Availability pt WHERE pt.ct_userid = pt_del_date.userid AND pt.avail_sd = pt_del_date.sd AND pt.avail_ed = pt_del_date.ed;
  END IF;
END;
$func$
LANGUAGE plpgsql;



-- Page 14
CREATE OR REPLACE FUNCTION for_gen_buttons(userid VARCHAR)
RETURNS TABLE(dur TEXT) AS
$func$
BEGIN
  RETURN QUERY(
  SELECT DISTINCT CONCAT(CAST(EXTRACT(MONTH FROM tmp.dur) AS INT),',',CAST(EXTRACT(YEAR FROM tmp.dur) AS INT)) AS mth_yr
  FROM ((SELECT la1.start_date AS dur FROM Looking_After la1 WHERE la1.ct_userid = for_gen_buttons.userid)
       UNION
       (SELECT la2.end_date AS dur FROM Looking_After la2 WHERE la2.ct_userid = for_gen_buttons.userid)) tmp
  ORDER BY mth_yr DESC);
END;
$func$
LANGUAGE plpgsql;



-- Page 15
CREATE OR REPLACE FUNCTION total_pet_day_mnth(userid VARCHAR, year INTEGER, month INTEGER)
RETURNS INTEGER AS
$func$
DECLARE
  firstday DATE := CAST(CONCAT(CAST(total_pet_day_mnth.year AS VARCHAR), '-', CAST(total_pet_day_mnth.month   AS VARCHAR),'-01') AS DATE);
  lastday DATE  := CAST(CONCAT(CAST(total_pet_day_mnth.year AS VARCHAR), '-', CAST(total_pet_day_mnth.month+1 AS VARCHAR),'-01') AS DATE);
BEGIN
  RETURN (
  SELECT 
  COALESCE((SELECT SUM(CAST(EXTRACT(DAY FROM la.end_date) AS INT) - CAST(EXTRACT(DAY FROM la.start_date) AS INT) + 1)
  FROM Looking_After la
  WHERE total_pet_day_mnth.userid = la.ct_userid
  AND la.start_date >= firstday AND la.end_date < lastday
  AND la.status = 'Completed' --Transaction occurs completely in this month
  GROUP BY la.ct_userid),0)
  +
  COALESCE((SELECT SUM(CAST(EXTRACT(DAY FROM lab.end_date) AS INT) - CAST(EXTRACT(DAY FROM firstday) AS INT) + 1)
  FROM Looking_After lab
  WHERE total_pet_day_mnth.userid = lab.ct_userid
  AND lab.start_date < firstday AND lab.end_date < lastday AND lab.end_date >= firstday
  AND lab.status = 'Completed' --Transaction starts before this month, but ends during
  GROUP BY lab.ct_userid),0)
  - 
  COALESCE((SELECT SUM(CAST(EXTRACT(DAY FROM lastday) AS INT) - CAST(EXTRACT(DAY FROM lac.start_date) AS INT) - 1)
  FROM Looking_After lac
  WHERE total_pet_day_mnth.userid = lac.ct_userid
  AND lac.start_date < lastday AND lac.start_date >= firstday AND lac.end_date > lastday
  AND lac.status = 'Completed' --Transaction starts during this month, but ends after
  GROUP BY lac.ct_userid),0)
  );
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
  lastday = date_trunc('month', firstday::date) + interval '1 month' - interval '1 day';
  RETURN 0 + COALESCE((SELECT sum(la.trans_pr)
  FROM Looking_After la
  WHERE userid = la.ct_userid
  AND la.start_date >= firstday AND la.end_date <= lastday
  AND la.status = 'Completed'), 0) --Transaction occurs completely in this month
  +
  COALESCE((SELECT sum(lab.trans_pr * (lab.end_date - firstday + 1)/(lab.end_date - lab.start_date + 1)) -- Multiplies trans_pr by no. of days that transaction was in this month
  FROM Looking_After lab
  WHERE userid = lab.ct_userid
  AND lab.start_date < firstday AND lab.end_date <= lastday AND lab.end_date >= firstday
  AND lab.status = 'Completed'), 0) --Transaction starts before this month, but ends during
  +
  COALESCE((SELECT sum(lac.trans_pr * (lastday - lac.start_date + 1)/(lac.end_date - lac.start_date + 1)) -- Multiplies trans_pr by no. of days that transaction was in this month
  FROM Looking_After lac
  WHERE userid = lac.ct_userid
  AND lac.start_date <= lastday AND lac.start_date >= firstday AND lac.end_date > lastday
  AND lac.status = 'Completed'), 0); --Transaction starts during this month, but ends after
END;
$func$
LANGUAGE plpgsql;



-- fulltime gets 3k for up to 60 petdays. excess pet days, 80% of price as bonus
-- pt 75% as payment
CREATE OR REPLACE FUNCTION what_salary(userid VARCHAR, dur DATE)
RETURNS FLOAT4 AS
$func$ --dur yearmonth is used
DECLARE
  earnings FLOAT;
BEGIN
  earnings = total_trans_pr_mnth (userid, CAST(EXTRACT(YEAR FROM dur) AS INT),CAST(EXTRACT(MONTH FROM dur) AS INT));
  IF (SELECT full_time FROM Caretaker ct WHERE ct.ct_userid = userid) THEN
    IF total_pet_day_mnth (userid, CAST(EXTRACT(YEAR FROM dur) AS INT), CAST(EXTRACT(MONTH FROM dur) AS INT)) <= 60 THEN
      RETURN 3000;
    ELSE
      RETURN 3000 + GREATEST((earnings - 3000) * 0.8,0);
    END IF;
  ELSE --parttime
    RETURN earnings * 0.75;
  END IF;
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
CREATE OR REPLACE FUNCTION find_birthday(userid VARCHAR, petname VARCHAR)
RETURNS DATE AS
$func$
BEGIN
RETURN (SELECT p.birthday FROM Pet p WHERE p.po_userid = userid AND p.pet_name = petname AND p.dead = 0);
END;
$func$
LANGUAGE plpgsql;



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
  IF NEW.status = 'Accepted' THEN
    UPDATE Looking_After la
    SET status = 'Rejected'
    WHERE la.po_userid = NEW.po_userid AND la.pet_name = NEW.pet_name AND la.status = 'Pending'
    AND NOT (la.start_date < NEW.start_date AND la.end_date < NEW.start_date)
    AND NOT (la.start_date > NEW.end_date AND la.end_date > NEW.end_date);
  END IF;
  RETURN NULL;
END;
$$
LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS cancel_pending_bids ON Looking_After;
CREATE TRIGGER cancel_pending_bids AFTER UPDATE OR INSERT ON Looking_After
FOR EACH ROW EXECUTE PROCEDURE trigger_pending_check();



CREATE OR REPLACE FUNCTION trigger_pt_avail_overlap_check()
RETURNS TRIGGER AS
$$ BEGIN
  IF EXISTS(SELECT 1 FROM PT_Availability pta WHERE NEW.ct_userid = pta.ct_userid AND NEW.avail_sd >= pta.avail_sd AND NEW.avail_ed <= pta.avail_ed) THEN
    RAISE EXCEPTION 'Error applying availability: You previously already indicated availability in this period';
  END IF;
  IF EXISTS(SELECT 1 FROM PT_Availability pta WHERE NEW.ct_userid = pta.ct_userid AND
  ( ( (NEW.avail_sd BETWEEN pta.avail_sd AND pta.avail_ed) AND NEW.avail_sd > pta.avail_ed )
  OR ( (NEW.avail_ed BETWEEN pta.avail_sd AND pta.avail_ed) AND NEW.avail_sd < pta.avail_sd ) ) ) THEN
    RAISE EXCEPTION 'Error applying availability: Overlaps with a previously applied availability';
  END IF;
  
  DELETE FROM PT_Availability pta WHERE NEW.ct_userid = pta.ct_userid AND NEW.avail_sd <= pta.avail_sd AND NEW.avail_ed >= pta.avail_ed; --Delete smaller availability interval
  RETURN NEW;
END;
$$
LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS overwrite_overlapping_avail ON PT_Availability;
CREATE TRIGGER overwrite_overlapping_avail BEFORE UPDATE OR INSERT ON PT_Availability
FOR EACH ROW EXECUTE PROCEDURE trigger_pt_avail_overlap_check();



CREATE OR REPLACE FUNCTION trigger_check_pet_owned()
RETURNS TRIGGER AS
$$ BEGIN
-- Stop caretakers from taking care of their own pet
  IF NEW.po_userid = NEW.ct_userid THEN
    RAISE EXCEPTION 'You cannot care for your own pet';
  END IF;
  RETURN NEW;
END;
$$
LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS disallow_ct_selfpet ON Looking_After;
CREATE TRIGGER disallow_ct_selfpet BEFORE UPDATE OR INSERT ON Looking_After
FOR EACH ROW EXECUTE PROCEDURE trigger_check_pet_owned();



CREATE OR REPLACE FUNCTION trigger_allow_review()
RETURNS TRIGGER AS
$$ BEGIN
-- Allow review to be written only after transaction completed
  IF NEW.review IS NULL OR NEW.status = 'Completed' THEN
    RETURN NEW;
  ELSE
    RAISE EXCEPTION 'Transaction not completed, cannot write review';
  END IF;
END;
$$
LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS review_after_completion ON Looking_After;
CREATE TRIGGER review_after_completion BEFORE UPDATE OR INSERT ON Looking_After
FOR EACH ROW EXECUTE PROCEDURE trigger_allow_review();



CREATE OR REPLACE FUNCTION trigger_pt_price()
RETURNS TRIGGER AS
$$ BEGIN
-- If attempting to update/insert pt price, make sure its above base price
  IF NEW.price < (SELECT p.price FROM Pet_Type p WHERE p.pet_type = NEW.pet_type) THEN
    NEW.price := (SELECT p.price FROM Pet_Type p WHERE p.pet_type = NEW.pet_type);
  END IF;
  RETURN NEW;
END;
$$
LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS pt_min_price ON PT_validpet;
CREATE TRIGGER pt_min_price BEFORE UPDATE OR INSERT ON PT_validpet
FOR EACH ROW EXECUTE PROCEDURE trigger_pt_price();