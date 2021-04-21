#!/bin/bash

squeue -u $USER -h -o %A | xargs scancel
rm *.out core*
