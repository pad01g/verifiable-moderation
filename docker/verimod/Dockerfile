FROM ubuntu:latest
RUN apt update
RUN apt install -y git
RUN apt install -y python3
RUN apt install -y python3-setuptools
RUN apt install -y libgmp-dev python3-pip

COPY requirements.txt /app/requirements.txt
COPY src/ /app/

WORKDIR /app

RUN pip install -r requirements.txt

RUN git clone https://github.com/starkware-libs/starkex-resources/ /usr/src/cairolib
RUN cd /usr/src/cairolib/crypto && python3 setup.py install

CMD ["bash", "-c", "while sleep 5; do :; done"]
