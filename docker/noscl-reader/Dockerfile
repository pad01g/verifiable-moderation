FROM ubuntu:latest
RUN apt update
RUN apt install -y wget
RUN wget -O/usr/local/bin/noscl https://github.com/fiatjaf/noscl/releases/download/v0.6.0/noscl
RUN chmod +x /usr/local/bin/noscl

RUN apt install -y python3
RUN apt install -y python3-setuptools
RUN apt install -y libgmp-dev python3-pip
RUN apt install -y jq
RUN apt install -y curl
RUN apt install -y git

# 844ac3dcb1f735451457f7eecc6e37cd96d1cb2d
RUN git clone https://github.com/starkware-libs/starkex-resources/ /usr/src/cairolib
RUN cd /usr/src/cairolib/crypto && python3 setup.py install

RUN pip install cairo-lang

CMD ["bash", "-c", "while sleep 5; do :; done"]
