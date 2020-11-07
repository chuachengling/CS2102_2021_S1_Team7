-- PART-TIME, AVAILABILITY, FULL-TIME, LEAVE --

CREATE TABLE PT_Availability (
	ct_userid 	VARCHAR NOT NULL REFERENCES Caretaker (ct_userid),
	avail_sd 	DATE NOT NULL,
	avail_ed 	DATE NOT NULL,
	CHECK (date(avail_sd) <= date(avail_ed)),
	PRIMARY KEY (ct_userid, avail_sd, avail_ed)
);

CREATE TABLE FT_Leave (
	ct_userid 	VARCHAR NOT NULL REFERENCES Caretaker (ct_userid),
	leave_sd 	DATE NOT NULL,
	leave_ed 	DATE NOT NULL,
	CHECK (date(leave_sd) <= date(leave_ed)),
	PRIMARY KEY (ct_userid, leave_sd, leave_ed)
);


-- LOOKING AFTER --

CREATE TABLE Looking_After (
	po_userid 	VARCHAR NOT NULL,
	ct_userid 	VARCHAR NOT NULL REFERENCES Caretaker (ct_userid) ON UPDATE CASCADE,
	pet_name 	VARCHAR NOT NULL,
	dead 		INTEGER DEFAULT 0,
	start_date 	DATE NOT NULL,
	end_date 	DATE NOT NULL,
	status 		VARCHAR NOT NULL DEFAULT 'Pending' CHECK(status = 'Completed' OR status = 'Accepted' OR status = 'Pending' OR status = 'Rejected'),
	trans_pr 	FLOAT4 NOT NULL CHECK(trans_pr > 0),
	payment_op 	VARCHAR NOT NULL CHECK(payment_op = 'Credit Card' OR payment_op = 'Cash'),
	rating 		FLOAT8 DEFAULT NULL,
	review 		VARCHAR DEFAULT NULL,
	CHECK (date(start_date) <= date(end_date)),
	PRIMARY KEY (po_userid, ct_userid, pet_name, dead, start_date, end_date),
	FOREIGN KEY (po_userid, pet_name, dead) REFERENCES Pet (po_userid, pet_name, dead) ON UPDATE CASCADE
);


-- CHAT --

CREATE TABLE Chat (
	po_userid 	VARCHAR,
	ct_userid 	VARCHAR,
	pet_name 	VARCHAR,
	dead		INTEGER NOT NULL,
	start_date 	DATE NOT NULL,
	end_date 	DATE NOT NULL,
	time 		TIMESTAMPTZ,
	sender 		INTEGER CHECK (sender = 1 OR sender = 2 OR sender = 3),
	text 		VARCHAR,
	FOREIGN KEY (po_userid, ct_userid, pet_name, dead, start_date, end_date) REFERENCES Looking_After (po_userid, ct_userid, pet_name, dead, start_date, end_date) ON UPDATE CASCADE,
	PRIMARY KEY (po_userid, ct_userid, pet_name, dead, start_date, end_date, time, sender)
);