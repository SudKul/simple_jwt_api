# Deploying Flask API

## Initial setup
1. Go to the Github starter project: TODO: add URL
2. Fork this project by pressing the fork buton
3. Locally clone your Forked version. You can now begin modifying it. 

## Containarizing and Running Locally
The supplied flask app is a very simple api with two endpoints. One which returns a jwt token, the other which requires a valid jwt token, and returns the un-encrpyted contents of that token. 

### Run the Api using Flask Server
1.  Install python dependencies. These dependencies are kept in a requirements.txt file. To install them, use pip:

```bash
pip install -r requirements.txt
```

2. Setting up environment

The following environment variable is required:

JWT_SECRET - The secret used to make the JWT token, for the purpose of this course it can be any string.

The following environment variable is optional:

LOG_LEVEL - The level of logging. Will default to 'INFO', but when debugging an app locally, you may want to set it to 'DEBUG'

```bash
export JWT_SECRET=myjwtsecret
export LOG_LEVEL=DEBUG
```

3. Run the app using the Flask server, from the flask-app directory, run:
```bash
python app/main.py
```
To try the api endpoints, open a new shell and run, replacing '<EMAIL>' and '<PASSWORD>' with and any values:
```bash
export TOKEN=`curl -d '{"email":"<EMAIL>","password":"<PASSWORD>"}' -H "Content-Type: application/json" -X POST localhost:80/auth  | jq -r '.token'`
```

This calls the endpoint 'localhost:80/auth' with the '{"email":"<EMAIL>","password":"<PASSWORD>"}' as the message body. The return value is a jwt token based on the secret you supplied. We are assigning that secret to the environment variable 'TOKEN'. To see the jwt token, run:
```bash
echo $TOKEN
```
To call the 'contents' endpoint, which decrpyts the token and returns it content, run:
```bash
curl --request GET 'http://127.0.0.1:80/contents' -H "Authorization: Bearer ${TOKEN}" | jq .
```
You should see the email that you passed in as one of the values.

### Dockerize and Run Locally

1. Install Docker
Use the installation instructions supplied here: https://docs.docker.com/install/

2. Create a Docker file. A Docker file decribes how to build a Docker image. Create a file named 'Dockerfile' in the app repo. The contents of the file describe the steps in creating a Docker image.  The contents of the file should be:
```
FROM python:stretch

COPY . /app
WORKDIR /app

RUN apt-get update -y
RUN apt-get install -y  
RUN pip install -r requirements.txt

ENTRYPOINT ["gunicorn", "-b", ":8080", "main:APP"]
```
FROM python:stretch

COPY . /app
WORKDIR /app

RUN apt-get update -y
RUN apt-get install -y  
RUN pip install -r requirements.txt

ENTRYPOINT ["gunicorn", "-b", ":8080", "main:APP"]
```
3. Create a file named 'env_file' and use it to set the environment variables which will be run locally in your container. Here we do not need the export command:

```
JWT_SECRET=myjwtsecret
LOG_LEVEL=DEBUG
```
4. Build a Local Docker Image
To build a Docker image run:
```
docker build -t jwt-api-test app/
```
5. Run the image locally, using the 'gunicorn' server:
```bash
docker run --env-file=env_file -p 80:8080 jwt-api-test
```
To use the endpoints use the same curl commands as before:

```bash
export TOKEN=`curl -d '{"email":"<EMAIL>","password":"<PASSWORD>"}' -H "Content-Type: application/json" -X POST localhost:80/auth  | jq -r '.token'`
curl --request GET 'http://127.0.0.1:80/contents' -H "Authorization: Bearer ${TOKEN}" | jq .
```

## Deployment to Kubernetes using CodePipeline, CodeBuild, and Lambda

### Deploy a Kubernetes Cluster

1. Install  aws cli
```bash
pip install awscli --upgrade --user 
```
Note: If you are using a Python virtual environment, the command will be:
```bash 
pip install awscli --upgrade
```
2. Generate aws access key
Generate a aws access key id and secret key:
https://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html#access-keys-and-secret-access-keys 

3. Setup your environment to use these keys:
If you not already have a aws 'credentials' file setup, run:
```bash
aws configure
```
And use the credentials you generated in step 2. Your aws commandline tools will now use these credentials.

4. Install the 'eksctl' tool.
The 'eksctl' tool allow interaction wth a EKS cluster from the command line. To install, follow the directions for your platform outlined here: https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html 

5. Create a EKS cluster
```bash
eksctl create cluster  --name prod-06031338  --version 1.12  --nodegroup-name standard-workers  --node-type t3.nano  --nodes 3  --nodes-min 1  --nodes-max 4  --node-ami auto
```
This will take some time to do. Progress can be checked by visiting the aws console and selecting EKS from the services. 

6. Check the cluster is ready
```bash
kubectl get nodes
```

7. Create an IAM role that CodeBuild can use to interact with EKS
```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

TRUST="{ \"Version\": \"2012-10-17\", \"Statement\": [ { \"Effect\": \"Allow\", \"Principal\": { \"AWS\": \"arn:aws:iam::${ACCOUNT_ID}:root\" }, \"Action\": \"sts:AssumeRole\" } ] }"

echo '{ "Version": "2012-10-17", "Statement": [ { "Effect": "Allow", "Action": [ "eks:Describe*", "ssm:GetParameters" ], "Resource": "*" } ] }' > /tmp/iam-role-policy 

aws iam create-role --role-name UdacityFlaskDeployCBKubectlRole --assume-role-policy-document "$TRUST" --output text --query 'Role.Arn'

aws iam put-role-policy --role-name UdacityFlaskDeployCBKubectlRole --policy-name eks-describe --policy-document file:///tmp/iam-role-policy

```
8. Grant role access to the cluster.
The 'aws-auth ConfigMap' is used to grant role based access control to your cluster. 
```
ROLE="    - rolearn: arn:aws:iam::$ACCOUNT_ID:role/UdacityFlaskDeployCodeBuildKubectlRole\n      username: build\n      groups:\n        - system:masters"
kubectl get -n kube-system configmap/aws-auth -o yaml | awk "/mapRoles: \|/{print;print \"$ROLE\";next}1" > /tmp/aws-auth-patch.yml
kubectl patch configmap/aws-auth -n kube-system --patch "$(cat /tmp/aws-auth-patch.yml)"
```
9. Generate a GitHub access token.
A Github acces token will allow CodePipeline to monitor when a repo is changed. A token can be generated here: https://github.com/settings/tokens/=
This token should be saved somewhere that is secure.

10. TODO add buildspec.yml 
11.  Put secrets into AWS Parameter Store 
```
aws ssm put-parameter --name JWT_SECRET --value "YourJWTSecret" --type SecureString
```
TODO: modify CodePipeline template

11. Create a stack for CodePipeline
Go the the CloudFormation service in the aws console. Press the 'Create Stack' button. Choose the 'Upload template to S3' option and upload the template modified in step 11. Press 'Next'. Give the stack a name, fill in your GitHub login and the Github access token generated in step 9. 
TODO add image here

12. Check the pipeline works
Commit a change to the master branch of the repo. Then , in the aws console go to the CodePipeline UI. 


