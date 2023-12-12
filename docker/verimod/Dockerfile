FROM ubuntu:latest
RUN apt update
RUN apt install -y git
RUN apt install -y python3
RUN apt install -y python3-setuptools
RUN apt install -y libgmp-dev python3-pip
RUN apt install -y jq
RUN apt install -y curl

# 844ac3dcb1f735451457f7eecc6e37cd96d1cb2d
RUN git clone https://github.com/starkware-libs/starkex-resources/ /usr/src/cairolib
RUN cd /usr/src/cairolib/crypto && python3 setup.py install

COPY requirements.txt /app/requirements.txt

WORKDIR /app

RUN pip install -r requirements.txt

COPY src/ /app/

# generate input
RUN python3 ./cli/generate-input.py ./cairo/verifiable-moderation-input.json

# generate config.json from input
RUN python3 ./cli/generate-config.py ./cairo/verifiable-moderation-input.json ./server/config.template.json ./server/config.json

# run migration
RUN python3 ./server/manage.py migrate

# generate block.json
RUN cat ./cairo/verifiable-moderation-input.json | jq '{ "block": .blocks[4] }' > ./server/block.good.json
RUN cat ./cairo/verifiable-moderation-input.json | jq '{ "block": .blocks[3] }' > ./server/block.bad.json

CMD ["python3", "./server/manage.py", "runserver", "0.0.0.0:8000"]
