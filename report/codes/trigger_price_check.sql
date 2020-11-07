CREATE OR REPLACE FUNCTION trigger_price_check()
RETURNS TRIGGER AS
$$
DECLARE
	baseprice FLOAT4;
BEGIN
	-- Stores the new prices for each pet type that was updated
	baseprice = (SELECT price FROM Pet_Type WHERE pet_type = NEW.pet_type);

	-- Increase prices set by Part-time Caretakers if they would fall below this new price
	UPDATE PT_validpet
	SET price = baseprice
	WHERE (PT_validpet.ct_userid, PT_validpet.pet_type) IN (
		SELECT pt.ct_userid,pt.pet_type
		FROM PT_validpet pt
		INNER JOIN Pet_Type base
		ON pt.pet_type = base.pet_type
		WHERE pt.price < base.price
	);

	RETURN NULL;
END;
$$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS admin_changed_price ON Pet_Type;

CREATE TRIGGER admin_changed_price AFTER UPDATE ON Pet_Type
FOR EACH ROW EXECUTE PROCEDURE trigger_price_check();