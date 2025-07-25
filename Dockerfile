FROM python:3.9
WORKDIR /app
RUN apt-get update && apt-get install -y     libpq-dev     gcc     && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && pip install --no-cache-dir -r requirements.txt
COPY web/ .
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "goit.wsgi:application"]
