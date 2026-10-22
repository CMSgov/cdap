# Use the official, secure Amazon Linux 2023 minimal image from AWS ECR
FROM public.ecr.aws/amazonlinux/amazonlinux:2023-minimal

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Install Python 3, Pip, and clean the cache to keep the layer small
RUN dnf update -y && \
    dnf install -y python3 python3-pip && \
    dnf clean all

# Establish working directory
WORKDIR /app

# Copy and install requirements separately to leverage Docker layer caching
COPY src/ops/containers/e2e .
RUN pip3 install --no-cache-dir -r requirements.txt

# Specify the command to run your app
CMD ["python3", "/app/e2e.py", "--env", "config-container.json"]