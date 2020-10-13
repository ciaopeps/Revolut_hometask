-- CREATE TABLES TO CREATE SCHEMA BEFORE IMPORTING CSV TABLES
CREATE TABLE transactions (
	currency character(3) not null,
	amount bigint not null,
	state varchar(25) not null,
	created_date timestamp without time zone not null,
	merchant_category varchar(100),
	merchant_country varchar(3),
	entry_method varchar(4) not null,
	user_id uuid not null,
	type varchar(20) not null,
	source varchar(20) not null,
	id uuid primary key
);

CREATE TABLE users (
	id uuid primary key,
	has_email boolean not null,
	phone_country varchar(300),
	terms_version date,
	created_date timestamp without time zone not null,
	state varchar(25) not null,
	country varchar(2),
	birth_year integer,
	kyc varchar(20),
	failed_sign_in_attempts integer
);

CREATE TABLE fx_rates (
	base_ccy varchar(3),
	ccy varchar(10),
	rate double precision,
	primary key(base_ccy, ccy)
);

CREATE TABLE currency_details (
	ccy varchar(10) primary key,
	iso_code integer,
	exponent integer,
	is_crypto boolean not null
);

-- QUERY ONE - Fixed version

WITH processed_users
    AS ( SELECT LEFT (u.phone_country , 2 ) AS short_phone_country , u.id
        FROM users u)

SELECT  t.user_id ,
        t.merchant_country ,
        Sum (t.amount / fx.rate / Power ( 10 , cd.exponent)) AS amount

FROM transactions t
    JOIN fx_rates fx
      ON ( fx.ccy = t.currency
        AND fx.base_ccy = 'EUR' )
    JOIN currency_details cd
      ON cd.ccy = t.currency --currency should be ccy
    JOIN processed_users pu
      ON pu.id = t.user_id

WHERE t.source = 'GAIA'
    AND pu.short_phone_country = LEFT(t.merchant_country,2) -- different format country code
GROUP BY t.user_id ,
    t.merchant_country
ORDER BY amount DESC ;

-- QUERY TWO

 WITH dates as ( with usid AS (
                                SELECT
                                    t.user_id,
                                    min(t.created_date) as mindate
                                FROM transactions t
                                GROUP BY 1
                                order by 1

                                )

                select usid.user_id, usid.mindate, t.amount,t.currency
                from usid
                INNER JOIN transactions t on (t.user_id = usid.user_id AND t.created_date = usid.mindate)
                WHERE
                t.state = 'COMPLETED' AND
                t.type = 'CARD_PAYMENT'),

amounts AS (
SELECT d.user_id,
    CASE WHEN d.currency!='USD'
         THEN f.rate * (d.amount/ Power ( 10 , cd.exponent))
         ELSE 1 * (d.amount/  Power ( 10 , cd.exponent))
    END AS amount_usd

FROM dates d
LEFT JOIN fx_rates f ON (d.currency=f.ccy and f.base_ccy = 'USD')
JOIN currency_details cd ON cd.ccy = d.currency
)
SELECT user_id
FROM amounts
WHERE amount_usd > 10;
