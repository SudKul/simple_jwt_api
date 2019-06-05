FROM python:stretch

COPY . /app
WORKDIR /app

RUN apt-get update -y
RUN apt-get install -y 
RUN pip install -r requirements.txt

ENTRYPOINT ["gunicorn", "-b", ":8080", "main:APP"]
