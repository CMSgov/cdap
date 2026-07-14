FROM python:3.13-alpine

WORKDIR /app

COPY requirements.txt .
RUN python -m pip install --no-cache-dir -r requirements.txt

COPY src/ .

CMD ["python", "main.py"]
