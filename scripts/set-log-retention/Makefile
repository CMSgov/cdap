# scripts/set_log_retention/Makefile
PYTHON := python3.13
VENV := .venv

.PHONY: install test test-cov lint plan clean

install:
	$(PYTHON) -m venv $(VENV)
	$(VENV)/bin/pip install --upgrade pip
	$(VENV)/bin/pip install -r requirements.txt
	@$(VENV)/bin/pip install -r requirements-dev.txt 2>/dev/null || \
		$(VENV)/bin/pip install pytest pytest-cov pylint

test: install
	$(VENV)/bin/pytest -v

test-cov: install
	mkdir -p coverage
	$(VENV)/bin/pytest --cov=. --cov-report=xml:coverage/coverage.xml

lint: install
	$(VENV)/bin/pylint set_log_retention.py

plan: install
	@echo "Requires an active AWS session in this shell (e.g. via Kion)."
	MODE=plan TARGET_ENV=$${TARGET_ENV:-test} $(VENV)/bin/python set_log_retention.py

clean:
	rm -rf $(VENV) coverage .pytest_cache __pycache__ retention-plan-*.json retention-report-*.csv
