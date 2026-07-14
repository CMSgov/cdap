FROM python:3.13-slim

RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --only-binary :all: -r requirements.txt

COPY src/ .

ENV DD_TRACE_AGENT_URL=http://localhost:8126

EXPOSE 8080

CMD ["ddtrace-run", "python", "main.py"]
