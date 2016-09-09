#!/bin/bash
sqlite3 ./data.sqlite <<!
.headers on
.mode csv
.separator ";"
.output data.csv
select * from data;
!
