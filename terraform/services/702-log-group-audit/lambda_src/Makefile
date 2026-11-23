SHELL := /bin/bash
PYTHON := python3.14
VENV := .venv

.PHONY: help venv install test test-cov lint clean

help:
	@echo "make install    - create venv, install runtime + dev deps"
	@echo "make test       - run unit tests (mocked, no AWS creds needed)"
	@echo "make test-cov   - run unit tests with coverage report"
	@echo "make lint       - run pylint"
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
	$(VENV)/bin/pylint lambda_function.py

clean:
	rm -rf $(VENV) coverage .coverage __pycache__ .pytest_cache
