FROM debian:stretch

RUN apt update && apt install -y sudo default-jre jq python3 zip
RUN apt upgrade

workdir /app
RUN mkdir payl
RUN mkdir pba

# Setup PAYL
workdir /app/payl
ADD ./payl ./
RUN ./setup.sh

# Setup PBA
workdir /app/pba
ADD ./polymorphic-blending ./
RUN ./setup.sh

# Add run (for Docker)
workdir /app
ADD ./run /app

CMD ["bash","run"]
