#!/bin/bash
qsub  -lmem=8192mb -lnodes=1:ppn=2 -lwalltime=4:00:00 -qinteractive -I  -Mla67@nyu.edu