FROM python:3.7.2-slim

COPY . /app
WORKDIR /app

RUN apt-get update -y
RUN apt-get install -y 
RUN pip install -r requirements.txt

RUN chmod 777 /tmp

ENTRYPOINT ["gunicorn", "-b", ":8080", "main:APP"]
