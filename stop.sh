#!/bin/bash
set -uex

# kill last time running tasks:
kill $(ps aux | grep 'demo_utils' | awk '{print $2}')
# tick.ts
# matchengine
# rollup_state_manager
# coordinator
# prover
