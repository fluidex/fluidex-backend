PROVER_DB="postgres://coordinator:coordinator_AA9944@127.0.0.1:5433/prover_cluster"
ROLLUP_DB="postgres://postgres:postgres_AA9944@127.0.0.1:5434/rollup_state_manager"
EXCHANGE_DB="postgres://exchange:exchange_AA9944@127.0.0.1:5432/exchange"

prover_db:
	psql $(PROVER_DB) 
exchange_db:
	psql $(EXCHANGE_DB)

prover_status:
	psql $(PROVER_DB) -c 'select status, count(*) from task group by status;'

shfmt:
	shfmt -i 2 -sr -w run.sh

list:
	ps aux|grep demo_utils|grep -v grep || true
new_trades:
	psql $(EXCHANGE_DB) -c 'select * from market_trade order by time desc limit 10;'

show_block:
	#psql $(ROLLUP_DB) -c 'select witness from l2block where block_id = 0' | cat
	psql $(ROLLUP_DB) -c 'select block_id, new_root from l2block' | cat

tail_log:
	ls rollup-state-manager/*.log prover-cluster/*.log dingir-exchange/*.log | xargs tail -n 3

clean_log:
	ls rollup-state-manager/*.log prover-cluster/*.log dingir-exchange/*.log | xargs rm
