PROVER_DB="postgres://coordinator:coordinator_AA9944@127.0.0.1:5433/prover_cluster"
prover_db:
	psql $(PROVER_DB) 

prover_status:
	psql $(PROVER_DB) -c 'select status, count(*) from task group by status;'

shfmt:
	shfmt -i 2 -sr -w run.sh
