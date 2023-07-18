FROM ubuntu:latest
RUN apt update
RUN apt install -y wget
RUN wget -O/usr/local/bin/noscl https://github.com/fiatjaf/noscl/releases/download/v0.6.0/noscl
RUN chmod +x /usr/local/bin/noscl
CMD ["bash", "-c", "while sleep 5; do :; done"]
