CREATE TABLE superiorresults (
	year int4, 
	bib int4, 
	first text, 
	last text, 
	sex text, 
	age int4, 
	city text, 
	state text, 
	country text, 
	splitrock interval, 
	beaverbay interval, 
	silverbay interval, 
	tettegouche interval, 
	cr6 interval, 
	finland interval, 
	crosby interval, 
	sugarloaf interval, 
	cramer interval, 
	temperance interval, 
	sawbill interval, 
	oberg interval, 
	finish interval
);
\copy superiorresults from 'superiorresults.csv' with csv header;

create sequence superiorresults_id_seq;

alter table superiorresults add column id int8 primary key default nextval('superiorresults_id_seq'::regclass);

CREATE VIEW superiorsplits AS
	SELECT id, splitrock, 'splitrock' as aid FROM superiorresults
	UNION ALL
	SELECT id, beaverbay, 'beaverbay' FROM superiorresults
	UNION ALL
	SELECT id, silverbay, 'silverbay' FROM superiorresults
	UNION ALL
	SELECT id, tettegouche, 'tettegouche' FROM superiorresults
	UNION ALL
	SELECT id, cr6, 'cr6' FROM superiorresults
	UNION ALL
	SELECT id, finland, 'finland' FROM superiorresults
	UNION ALL
	SELECT id, crosby, 'crosby' FROM superiorresults
	UNION ALL
	SELECT id, sugarloaf, 'sugarloaf' FROM superiorresults
	UNION ALL
	SELECT id, cramer, 'cramer' FROM superiorresults
	UNION ALL
	SELECT id, temperance, 'temperance' FROM superiorresults
	UNION ALL
	SELECT id, sawbill, 'sawbill' FROM superiorresults
	UNION ALL
	SELECT id, oberg, 'oberg' FROM superiorresults
	UNION ALL
	SELECT id, finish, 'finish' FROM superiorresults
;