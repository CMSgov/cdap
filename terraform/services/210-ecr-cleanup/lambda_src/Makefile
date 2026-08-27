SHELL := /bin/bash
PYTHON := python3.13
VENV := .venv

.PHONY: help venv install test test-cov lint dry-run check-aws clean

help:
	@echo "make install    - create venv, install runtime + dev deps"
	@echo "make test       - run unit tests (mocked, no AWS creds needed)"
	@echo "make test-cov   - run unit tests with coverage report"
	@echo "make lint       - run pylint"
	@echo "make dry-run    - run dry_run.py against real AWS (requires active Kion session)"
	@echo "make clean      - remove venv and generated artifacts"

$(VENV)/bin/activate:
	$(PYTHON) -m venv $(VENV)

venv: $(VENV)/bin/activate

install: venv
	$(VENV)/bin/pip install --upgrade pip
	$(VENV)/bin/pip install -r requirements.txt
	@if [ -f requirements-dev.txt ]; then \
		$(VENV)/bin/pip install -r requirements-dev.txt; \
	else \
		$(VENV)/bin/pip install pytest pytest-cov pylint; \
	fi

test: install
	$(VENV)/bin/pytest -v

test-cov: install
	mkdir -p coverage
	$(VENV)/bin/pytest --cov=. --cov-report=term-missing --cov-report=xml:coverage/coverage.xml

lint: install
	$(VENV)/bin/pylint lambda_function.py strategies.py dry_run.py

check-aws:
	@aws sts get-caller-identity > /dev/null 2>&1 || { \
		echo "No valid AWS credentials found in this shell."; \
		echo "Start (or refresh) your Kion session in this terminal, then re-run 'make dry-run'."; \
		exit 1; \
	}
	@echo "AWS session OK: $$(aws sts get-caller-identity --query Arn --output text)"

dry-run: install check-aws
	$(VENV)/bin/python dry_run.py --config-path dry_run_config.json

clean:
	rm -rf $(VENV) coverage .coverage __pycache__ .pytest_cache
