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

CREATE TABLE superiorsplits AS
WITH allsplits AS
	(SELECT id as runnerid, splitrock as split, 'splitrock' as aidstation FROM superiorresults WHERE splitrock < beaverbay
	UNION ALL
	SELECT id, beaverbay, 'beaverbay' FROM superiorresults WHERE beaverbay BETWEEN splitrock AND silverbay
	UNION ALL
	SELECT id, silverbay, 'silverbay' FROM superiorresults WHERE silverbay BETWEEN beaverbay AND tettegouche
	UNION ALL
	SELECT id, tettegouche, 'tettegouche' FROM superiorresults WHERE tettegouche BETWEEN silverbay and cr6
	UNION ALL
	SELECT id, cr6, 'cr6' FROM superiorresults WHERE cr6 BETWEEN tettegouche AND finland
	UNION ALL
	SELECT id, finland, 'finland' FROM superiorresults WHERE finland BETWEEN cr6 AND crosby
	UNION ALL
	SELECT id, crosby, 'crosby' FROM superiorresults WHERE crosby BETWEEN finland AND sugarloaf
	UNION ALL
	SELECT id, sugarloaf, 'sugarloaf' FROM superiorresults WHERE sugarloaf BETWEEN crosby AND cramer
	UNION ALL
	SELECT id, cramer, 'cramer' FROM superiorresults WHERE cramer BETWEEN sugarloaf AND temperance
	UNION ALL
	SELECT id, temperance, 'temperance' FROM superiorresults WHERE temperance BETWEEN cramer AND sawbill
	UNION ALL
	SELECT id, sawbill, 'sawbill' FROM superiorresults WHERE sawbill BETWEEN temperance AND oberg
	UNION ALL
	SELECT id, oberg, 'oberg' FROM superiorresults WHERE oberg BETWEEN sawbill AND finish
	UNION ALL
	SELECT id, finish, 'finish' FROM superiorresults WHERE finish > oberg
	)
	SELECT *, (SELECT finish FROM superiorresults WHERE id=allsplits.runnerid) as finish from allsplits WHERE split IS NOT NULL
;
