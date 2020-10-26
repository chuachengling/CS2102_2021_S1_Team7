#!/bin/bash

echo
echo "Concatenating scripts..."
cd processed
cat Accounts.txt Users.txt Admin.txt Pet_Owner.txt Caretaker.txt Pet_Type.txt PT_Availability.txt FT_Leave.txt > ../insertAll.sql
cd ..
echo "Scripts concatenated!"
