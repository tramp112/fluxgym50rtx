# Base image with CUDA 12.8
FROM nvidia/cuda:12.8.0-base-ubuntu20.04

# Install pip if not already installed

# Install Python 3.10 and pip
RUN apt-get update -y && \
    sed -i 's/http:\/\/archive\.ubuntu\.com\/ubuntu\//http:\/\/mirrors\.digitalocean\.com\/ubuntu\//g' /etc/apt/sources.list && \
    apt-get clean && \
    apt-get update -y && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update -y && \
    apt-get install -y \
    python3.10 \
    python3.10-dev \
    python3.10-distutils \
    curl \
    git \
    build-essential && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.10

# Make python3 point to python3.10
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1

# Install pip and development tools (no need for a separate apt-get update here)
RUN apt-get install -y \
    python3-pip \
    python3-dev \
    git \
    build-essential  # Install dependencies for building extensions

# Define environment variables for UID and GID and local timezone
ENV PUID=99
ENV PGID=100

# Create the 'appuser' user with the specified UID and using the existing GID 100
RUN useradd -u "$PUID" -g 100 -m appuser

WORKDIR /app

# Get sd-scripts from kohya-ss and install them
RUN git clone -b sd3 https://github.com/kohya-ss/sd-scripts && \
    cd sd-scripts && \
    sed -i '/bitsandbytes==0.44.0/s/^/#/' ./requirements.txt && \
    pip install --no-cache-dir -r ./requirements.txt

# Install main application dependencies
COPY ./requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r ./requirements.txt

# Install Torch, Torchvision, and Torchaudio for CUDA 12.8
#RUN pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu122/torch_stable.html
RUN pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128
RUN pip install -U bitsandbytes

# Change ownership to appuser:appuser
RUN chown -R appuser:100 /app

# Switch to the appuser
USER appuser

# delete redundant requirements.txt and sd-scripts directory within the container
RUN rm -r ./sd-scripts
RUN rm ./requirements.txt

#Run application as non-root
USER appuser

# Copy fluxgym application code
COPY . ./fluxgym

EXPOSE 7860

ENV GRADIO_SERVER_NAME="0.0.0.0"

WORKDIR /app/fluxgym

# Run fluxgym Python application
CMD ["python3", "./app.py"]
