-- DROPPING PAST TABLES --
DROP TABLE IF EXISTS Chat;
DROP TABLE IF EXISTS Looking_After;
DROP TABLE IF EXISTS FT_Leave;
DROP TABLE IF EXISTS PT_Availability;
DROP TABLE IF EXISTS Pet;
DROP TABLE IF EXISTS FT_validpet;
DROP TABLE IF EXISTS PT_validpet;
DROP TABLE IF EXISTS Pet_Type;
DROP TABLE IF EXISTS Caretaker;
DROP TABLE IF EXISTS Pet_Owner;
DROP TABLE IF EXISTS Admin;
DROP TABLE IF EXISTS Users;
DROP TABLE IF EXISTS Accounts;

-- GENERAL ACCOUNTS, USER AND ADMIN --

CREATE TABLE Accounts (
	userid 	VARCHAR PRIMARY KEY,
	password 	VARCHAR NOT NULL,
	deactivate 	BOOLEAN DEFAULT FALSE
);

CREATE TABLE Users (
	userid 	VARCHAR PRIMARY KEY REFERENCES Accounts (userid),
	name 		VARCHAR NOT NULL,
	postal 	INTEGER NOT NULL,
	address 	VARCHAR NOT NULL,
	hp 		INTEGER NOT NULL,
	email 	VARCHAR NOT NULL UNIQUE
);

CREATE TABLE Admin (
	userid 	VARCHAR PRIMARY KEY REFERENCES Accounts (userid)
);


-- PET OWNER, CARETAKER, PET TYPE --

CREATE TABLE Pet_Owner (
	po_userid 	VARCHAR PRIMARY KEY REFERENCES Users (userid) ON UPDATE CASCADE,
	credit 	INTEGER DEFAULT NULL
	
);

CREATE TABLE Caretaker (
	ct_userid 	VARCHAR PRIMARY KEY REFERENCES Users (userid) ON UPDATE CASCADE,
	bank_acc 	INTEGER NOT NULL,
	full_time 	BOOLEAN DEFAULT FALSE
);

CREATE TABLE Pet_Type (                             -- set by admin
	pet_type 	VARCHAR PRIMARY KEY NOT NULL,
	price 	FLOAT4 NOT NULL
);



-- VALID PET TYPES FOR CARETAKER, PET--
CREATE TABLE PT_validpet (                              -- set by PT
	ct_userid 	VARCHAR REFERENCES Caretaker (ct_userid) ON UPDATE CASCADE,
	pet_type 	VARCHAR NOT NULL REFERENCES Pet_type (pet_type),
	price 	FLOAT4 NOT NULL,
	PRIMARY KEY (ct_userid, pet_type)				-- check (pr >= admin set) kiv (use function)
);

CREATE TABLE FT_validpet (                               -- set by FT
	ct_userid 	VARCHAR REFERENCES Caretaker (ct_userid) ON UPDATE CASCADE,
pet_type 	VARCHAR NOT NULL REFERENCES Pet_type (pet_type)
);

CREATE TABLE Pet (
	po_userid 	VARCHAR NOT NULL REFERENCES Pet_Owner (po_userid),
	pet_name 	VARCHAR NOT NULL,
	dead 		INTEGER DEFAULT 0,
	birthday 	DATE DEFAULT NULL,
	spec_req 	VARCHAR DEFAULT NULL,
	pet_type 	VARCHAR NOT NULL REFERENCES Pet_Type (pet_type),
	PRIMARY KEY (po_userid, pet_name, dead)
);



-- PART-TIME, AVAILABILITY, FULL-TIME, LEAVE --

CREATE TABLE PT_Availability (
	ct_userid 	VARCHAR NOT NULL REFERENCES Caretaker (ct_userid),
	avail_sd 	DATE NOT NULL,
	avail_ed 	DATE NOT NULL,
	CHECK (date(avail_sd) <= date(avail_ed)),
	PRIMARY KEY (ct_userid, avail_sd, avail_ed)	     -- check constraint (ct_userid_full_time <> true) use function
);

CREATE TABLE FT_Leave (
	ct_userid 	VARCHAR NOT NULL REFERENCES Caretaker (ct_userid),
	leave_sd 	DATE NOT NULL,
	leave_ed 	DATE NOT NULL,
	CHECK (date(leave_sd) <= date(leave_ed)),
	PRIMARY KEY (ct_userid, leave_sd, leave_ed)	     -- check constraint (ct_userid_full_time = true) use function
);

-- LOOKING AFTER --

CREATE TABLE Looking_After (
	po_userid 	VARCHAR NOT NULL,
	ct_userid 	VARCHAR NOT NULL REFERENCES Caretaker (ct_userid) ON UPDATE CASCADE,
	pet_name 	VARCHAR NOT NULL,
	dead 		INTEGER DEFAULT 0,
	start_date 	DATE NOT NULL,
	end_date 	DATE NOT NULL,
	status 	VARCHAR NOT NULL DEFAULT 'Pending' CHECK(status = 'Completed' OR status = 'Accepted' OR status = 'Pending' OR status = 'Rejected'),
	trans_pr 	FLOAT4 NOT NULL CHECK(trans_pr > 0),
	payment_op 	VARCHAR NOT NULL CHECK(payment_op = 'Credit Card' OR payment_op = 'Cash'),
	rating 	INTEGER DEFAULT NULL,
	review 	VARCHAR DEFAULT NULL,
	CHECK (date(start_date) <= date(end_date)),
	PRIMARY KEY (po_userid, ct_userid, pet_name, start_date, end_date),
	FOREIGN KEY (po_userid, pet_name, dead) REFERENCES Pet (po_userid, pet_name, dead) ON UPDATE CASCADE
);


-- CHAT --

CREATE TABLE Chat (
	po_userid 	VARCHAR,
	ct_userid 	VARCHAR,
	pet_name 	VARCHAR,
	start_date 	DATE NOT NULL,
	end_date 	DATE NOT NULL,
	time 		TIMESTAMPTZ,
	sender 	INTEGER CHECK (sender = 1 OR sender = 2 OR sender = 3),
	text 		VARCHAR,
	FOREIGN KEY (po_userid, ct_userid, pet_name, start_date, end_date) REFERENCES Looking_After (po_userid, ct_userid, pet_name, start_date, end_date),
	PRIMARY KEY (po_userid, ct_userid, pet_name, start_date, end_date, time, sender)
);

-- SALARY (KIV) --

/* CREATE TABLE Salary (
	ct_userid 	VARCHAR NOT NULL,
	full_time 	BOOLEAN NOT NULL,
	year 		INTEGER CHECK (year <= 2020),
	month 	INTEGER CHECK (month <= 12 AND month >= 1),
	details 	VARCHAR,
	amount 	INTEGER,
	PRIMARY KEY (ct_userid, year, month),
	FOREIGN KEY (ct_userid, full_time) REFERENCES Caretaker(ct_userid, full_time)
); */

