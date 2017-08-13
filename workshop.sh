#!/bin/bash
export PGDATBASE=superior
sed -n '/^```sql/,/^```/ p' < index.md | sed '/^```/ d' > sqlcommands.sql
sed -n '/^```bash/,/^```/ p' < index.md | sed '/^```/ d' > bashcommands.sh
bash bashcommands.sh > testworkshop.txt
psql -f sqlcommands.sql >> testworkshop.txt