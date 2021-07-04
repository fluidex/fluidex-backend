#!/bin/bash
set -uex

# kill last time running tasks:
#kill $(ps aux | grep 'demo_utils' | grep -v grep | awk '{print $2}')
kill -9 $(ps aux | grep 'demo_utils' | grep -v grep | awk '{print $2}')
# tick.ts
# matchengine
# rollup_state_manager
# coordinator
# prover
