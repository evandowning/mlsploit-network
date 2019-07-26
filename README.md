# mlsploit-network

## Clone repository
```
$ git clone --recursive https://github.com/evandowning/mlsploit-network.git
```

## Tests
```
# Train
$ cp input/input_payl_train.json input/input.json
$ ./test.sh

# Evaluate
$ cp input/input_payl_eval.json input/input.json
$ ./test.sh

# Attack / Evaluate
$ cp input/input_pba.json input/input.json
$ ./test.sh
```

## MLsploit notes
  * Modify `mlsploit-execution-backend/mlsploit.py`
    * `Git(tmp_dir).clone(repo)` -> `Git(tmp_dir).clone(repo,recursive=True)`
  * Modify `run.sh` to contain folder where samples are located and mount on docker in `mlsploit-execution-backend/mlsploit.py`
    * Current path is variable `RAW` in `run.sh`
