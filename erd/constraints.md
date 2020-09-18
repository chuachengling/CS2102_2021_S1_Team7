## Entity and relationship requirements

* The application can have many **accounts**, each storing their own **user ID** and **password**.
	* An account can be uniquely identified by the UserID

* An **account** can either be an **admin account** or a **normal user**
	* This hierarchy satisfies covering constraints
	* This hierarchy does not satisfy overlapping constraints
		
* A **normal user** has a **profile picture**, **name**, **location**, **H/P number**, and **email**.

* A **normal user** can either be a **care taker** or a **pet owner**
	* This hierarchy satisfies covering constraints
	* This hierarchy satisfies overlapping constraints

* A **pet owner** may have a **credit card number** saved for future payments.

* A **pet owner** owns **pets**.

* A **pet** has a **profile picture**, **birthday**, **name**, **special requests** and a **pet ID**.
	* A pet can be uniquely identified with its pet ID. (Weak entity - existential dependency)
	
* A **pet** is an instance of a **pet type**.

* A **pet type** contains details about the **particular pet type** and also its **daily base price** (set by the administrator)

* A **care taker** may choose **what kind of pets they can care for**.

* A **care taker** has past **monthly salaries**, of which the **year**, **month** and **salary details** are stored
	* The salaries can be uniquely identified by the year, month and the care taker's user ID. (Weak entity - identity dependency) _(Can be derived with the main transaction table later, but created for caching purposes)_
	
* A **care taker** can either be a **part-timer** or a **full-timer**
	* This hierarchy satisfies covering constraints
	* This hierarchy does not satisfy overlapping constraints
	
* A **part-timer** can indicate his/her **availabilities** for a **period**, comprising of a start and end date (inclusive)

* A **full-timer** can indicate his/her **leave periods**, comprising of a start and end date (inclusive)

* A **caretaker** may **look after** a **pet** for a particular **period**, this will be termed as a transaction

* A **transaction** has a **status**, **transaction price**, **payment option**, **review** and **rating**
	* The status can either be 'Pending', 'Rejected', 'Accepted' or 'Completed' depending on the state of the transaction

* Each **transaction** can be accompanied by a series of **chat messages** which contains the **time sent** and the **text message** itself
	* A chat message can be uniquely identified with the sender (a user entity), time and the transaction's key (caretaker ID, pet owner ID, pet ID and time period) (Weak entity - identity dependency)
	
## Numerical diagram-enforceable constraints

* Pet owner - Pets	
	* A pet owner may own multiple pets
	* A pet must be owned by one owner

* Pets - Pet type
	* A pet must be classified under one pet type
	* A pet type classification may encompass many different pets

* Care taker - Pet type
	* A care taker may care for various kinds of pet types
	* Many care takers may care for the same pet type

* Care taker - Past salaries
	* A care taker may have multiple past salaries for the various years/months
	* Many care takers may have past salaries for the same year/month

* Part-timer - Availabilities
	* A part-timer may indicate availabilities for multiple periods
	* Many part-timers may indicate availabilities for the same period

* Full-timer - Leave
	* A full-timer may apply for leave for multiple periods
	* Many full-timers may apply for leave for the same period

* Looking after
	* A care taker may look after many pets
	* Many care takers may look after the same pet

## Numerical diagram-nonenforceable constraints

* A part-timer's availability periods cannot overlap
* A full-timer's leave periods cannot overlap
* A care taker cannot look after his/her own pet
* A review/rating for a transaction can only be filled after the transaction is marked as 'Completed'
* A pet that is being looked after by the care taker must be classified as one of the pet types that the care taker can care for
* Any two transactions that involve the same pet and do not have the status 'Rejected' cannot clash in terms of dates.
* The number of combined 'Accepted' and 'Completed' transactions for any care taker for any particular day cannot exceed 5 for a full-timer or highly rated part-timer, and cannot exceed 2 otherwise.
* A 'Accepted' or 'Completed' transaction for a care taker must fall within his/her availabilities (if he/she is a part-timer) and must not fall within his/her leave periods (if he/she is a full-timer)
* A 'Pending' transaction for a care taker that cannot take up the transaction (because of the pet limit or otherwise) must immediately be marked as 'Rejected'

## Other assumptions
* There is only one admin account
* The admin will create a new account if he/she wishes to use the PCS
* The pet types that the care taker can care for is fixed and will not change