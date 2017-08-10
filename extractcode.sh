#!/bin/bash
sed -n '/^```sql/,/^```/ p' < README.md | sed '/^```/ d' > README.sql
sed -n '/^```bash/,/^```/ p' < README.md | sed '/^```/ d' > README.sh