PROVER_DB="postgres://coordinator:coordinator_AA9944@127.0.0.1:5433/prover_cluster"
ROLLUP_DB="postgres://postgres:postgres_AA9944@127.0.0.1:5434/rollup_state_manager"
EXCHANGE_DB="postgres://exchange:exchange_AA9944@127.0.0.1:5432/exchange"

prover_db:
	psql $(PROVER_DB) 
exchange_db:
	psql $(EXCHANGE_DB)
rollup_db:
	psql $(ROLLUP_DB)

prover_status:
	psql $(PROVER_DB) -c "select status, count(*) from task group by status UNION ALL SELECT null status, COUNT(status) from task"

shfmt:
	shfmt -i 2 -sr -w *.sh

list:
	ps aux|grep fluidex-backend|grep -v grep || true
new_trades:
	psql $(EXCHANGE_DB) -c 'select * from market_trade order by time desc limit 10;'

block_input:
	psql $(ROLLUP_DB) -c 'select block_id, witness from l2block order by block_id desc limit 1' | cat
block_root:
	psql $(ROLLUP_DB) -c 'select block_id, new_root from l2block order by block_id desc limit 1' | cat

tail_log:
	ls rollup-state-manager/*.log prover-cluster/*.log dingir-exchange/*.log | xargs tail -n 3

clean_log:
	ls rollup-state-manager/*.log prover-cluster/*.log dingir-exchange/*.log | xargs rm
