-- GENERAL ACCOUNTS, USER AND ADMIN --

CREATE TABLE Accounts (
	userid		VARCHAR PRIMARY KEY,
	password	VARCHAR NOT NULL,
	deactivate	BOOLEAN DEFAULT FALSE
);

CREATE TABLE Users (
	userid		VARCHAR PRIMARY KEY REFERENCES Accounts (userid),
	name		VARCHAR NOT NULL,
	postal		INTEGER NOT NULL,
	address		VARCHAR NOT NULL,
	hp		INTEGER NOT NULL,
	email		VARCHAR NOT NULL UNIQUE
);

CREATE TABLE Admin (
	userid		VARCHAR PRIMARY KEY REFERENCES Accounts (userid)
);


-- PET OWNER, CARETAKER, PET TYPE --

CREATE TABLE Pet_Owner (
	po_userid	VARCHAR PRIMARY KEY REFERENCES Users (userid) ON UPDATE CASCADE,
	credit		CHAR(16) DEFAULT NULL
);

CREATE TABLE Caretaker (
	ct_userid	VARCHAR PRIMARY KEY REFERENCES Users (userid) ON UPDATE CASCADE,
	bank_acc	CHAR(10) NOT NULL,
	full_time	BOOLEAN DEFAULT FALSE
);

CREATE TABLE Pet_Type (
	pet_type	VARCHAR PRIMARY KEY NOT NULL,
	price		FLOAT4 NOT NULL
);


-- VALID PET TYPES FOR CARETAKER, PET --

CREATE TABLE PT_validpet (
	ct_userid	VARCHAR REFERENCES Caretaker (ct_userid) ON UPDATE CASCADE,
	pet_type	VARCHAR NOT NULL REFERENCES Pet_type (pet_type),
	price		FLOAT4 NOT NULL,
	PRIMARY KEY (ct_userid, pet_type)
);

CREATE TABLE FT_validpet (
	ct_userid	VARCHAR REFERENCES Caretaker (ct_userid) ON UPDATE CASCADE,
	pet_type	VARCHAR NOT NULL REFERENCES Pet_type (pet_type)
);

CREATE TABLE Pet (
	po_userid	VARCHAR NOT NULL REFERENCES Pet_Owner (po_userid),
	pet_name	VARCHAR NOT NULL,
	dead		INTEGER NOT NULL DEFAULT 0,
	birthday	DATE DEFAULT NULL,
	spec_req	VARCHAR DEFAULT NULL,
	pet_type	VARCHAR NOT NULL REFERENCES Pet_Type (pet_type),
	PRIMARY KEY (po_userid, pet_name, dead)
);