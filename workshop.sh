#!/bin/bash -x
export PGDATBASE=superior
sed -n '/^```sql/,/^```/ p' < index.md | sed '/^```/ d' > sqlcommands.sql
sed -n '/^```bash/,/^```/ p' < index.md | sed '/^```/ d' > bashcommands.sh
bash -x bashcommands.sh > testworkshop.txt
psql -a -f sqlcommands.sql superior >> testworkshop.txt