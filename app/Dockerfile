FROM python:3.12-slim

# Flush logs straight to stdout so they reach AppServiceConsoleLogs.
ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PORT=8080

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY main.py .

EXPOSE 8080

# Shell form so ${PORT} (set by App Service via app settings) is expanded.
CMD ["sh", "-c", "exec uvicorn main:app --host 0.0.0.0 --port ${PORT}"]
