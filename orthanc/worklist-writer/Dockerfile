FROM python:3.11-alpine

# Set system variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

# 1. Install build tools, 2. Pip install packages, 3. Remove build tools to save space
RUN apk add --no-cache --virtual .build-deps gcc musl-dev libffi-dev \
    && pip install --no-cache-dir pynetdicom requests pydicom \
    && apk del .build-deps

# Copy your local application directory into the container
COPY . /app/

# Expose the internal port for the writer API
EXPOSE 8000

# Set the default runtime command
CMD ["python", "app.py"]
