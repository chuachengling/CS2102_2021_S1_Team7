#!/bin/bash

echo
echo "Concatenating scripts..."
cd processed
cat Accounts.txt Users.txt Admin.txt Pet_Owner.txt Caretaker.txt Pet_Type.txt > ../insertAll.sql
cd ..
echo "Scripts concatenated!"
