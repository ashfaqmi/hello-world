# hello-world
Blue Green deployment of nodeJS app on Google Kubenetes engine using Spinnaker and Helm

This document explains how to configure Blue Green deployment of a nodeJS application on Google Kubernetes Engine using Spinnaker and Helm.

**As a prerequisite, enable the APIs needed on GCP**

- Kubernetes API
- Compute API
- Resource Manager API
- IAM API


**Set Up a Kubernetes Cluster**

- Go to the Console and scroll the left panel down to Compute->Kubernetes Engine->Kubernetes Clusters.
- Click Create Cluster.
- Choose a name or leave as the default one.
- Under Machine Type, click Customize.
- Allocate at least 2 vCPU and 10GB of RAM.
- Change the cluster size to 2.
- Enable Legacy Authorization while customizing the cluster.
- click Create.

In a minute or two the cluster will be created and ready to go.

![](Images/Kubernetes%20Cluster.PNG)

![](Images/Kubernetes%20Nodes.PNG)


**Configure identity and access management**

Create a Cloud Identity and Access Management (Cloud IAM) service account to delegate permissions to Spinnaker, allowing it to store data in Cloud Storage. Spinnaker stores its pipeline data in Cloud Storage to ensure reliability and resiliency. If our Spinnaker deployment unexpectedly fails, we can create an identical deployment in minutes with access to the same pipeline data as the original.

1. Create a service account:

`$ gcloud iam service-accounts create spinnaker-storage-account --display-name spinnaker-storage-account`

2. Store the service account email address and our current project ID in environment variables for use in later commands:

`$ export SA_EMAIL=$(gcloud iam service-accounts list --filter="displayName:spinnaker-storage-account" --format='value(email)')`
`$ export PROJECT=$(gcloud info --format='value(config.project)')`

3. Bind the storage.admin role to our service account:

`$ gcloud projects add-iam-policy-binding $PROJECT --role roles/storage.admin --member serviceAccount:$SA_EMAIL`

4. Download the service account key. We will need this key later while installing Spinnaker and we need to also upload the key to Kubernetes Engine.

`$ gcloud iam service-accounts keys create spinnaker-sa.json — iam-account $SA_EMAIL`


**Deploying Spinnaker using Helm**

1. Download and install the helm binary:

`$ wget https://storage.googleapis.com/kubernetes-helm/helm-v2.9.0-linux-amd64.tar.gz`

2. Unzip the file to your local system:

`$ tar zxfv helm-v2.9.0-linux-amd64.tar.gz`
`$ sudo chmod +x linux-amd64/helm && sudo mv linux-amd64/helm /usr/bin/helm`

3. Grant Tiller, the server side of Helm, the cluster-admin role in your cluster:

`$ kubectl create clusterrolebinding user-admin-binding --clusterrole=cluster-admin --user=$(gcloud config get-value account)`
`$ kubectl create serviceaccount tiller --namespace kube-system`
`$ kubectl create clusterrolebinding tiller-admin-binding --clusterrole=cluster-admin --serviceaccount=kube-system:tiller`

4. Grant Spinnaker the cluster-admin role so it can deploy resources across all namespaces:

`$ kubectl create clusterrolebinding --clusterrole=cluster-admin --serviceaccount=default:default spinnaker-admin`

5. Initialize Helm to install Tiller in your cluster:

`$ helm init --service-account=tiller --upgrade`
`$ helm repo update`

6. Ensure that Helm is properly installed by running the following command. If Helm is correctly installed, v2.9.0 appears for both client and server.

`$ helm version`


**Configure Spinnaker**

1. Create a bucket for Spinnaker to store its pipeline configuration:

`$ export PROJECT=$(gcloud info --format='value(config.project)')`
`$ export BUCKET=$PROJECT-spinnaker-configgsutil mb -c regional -l us-central1 gs://$BUCKET`

2. Create the configuration file:

```
$ export SA_JSON=$(cat spinnaker-sa.json)
$ export PROJECT=$(gcloud info --format='value(config.project)')
$ export BUCKET=$PROJECT-spinnaker-config
$ cat > spinnaker-config.yaml <<EOF
storageBucket: $BUCKET
gcs:  
 enabled: true
 project: $PROJECT  
 jsonKey: '$SA_JSON'

# Disable minio as the default
minio:
 enabled: false

# Configure your Docker registries here
accounts:
- name: gcr 
 address: https://gcr.io
 username: _json_key  
 password: '$SA_JSON'
 email: muhammedashfaqmi@gmail.com
EOF
```

**Deploy the Spinnaker chart**

Use the Helm command-line interface to deploy the chart with the configuration set earlier. This command typically takes five to ten minutes to complete, so we will be providing a deploy timeout with ` — timeout`.

`$ helm install -n cd stable/spinnaker -f spinnaker-config.yaml --timeout 600 --version 0.3.1`

2. After the command completes, run the following command to set up port forwarding to the Spinnaker UI from Cloud Shell:

`$ export DECK_POD=$(kubectl get pods --namespace default -l  "component=deck" -o jsonpath="{.items[0].metadata.name}")`
`$ kubectl port-forward --namespace default $DECK_POD 8080:9000 >> /dev/null &`

To access Spinnaker from browser, expose and open port 30145.

`$ gcloud compute firewall-rules create gke-kube-cluster-2-default-pool-32c8d9b5-9jvb --allow tcp:30145`

http://35.238.154.244:30145/#/infrastructure

**Spinnaker UI**

![](Images/Spinnaker%20UI.PNG)


**Building the container image**\


1. Create a simple "Hello World" nodeJS app.

`$ vi helloWorld.js`

`$ cat helloWorld.js`

```
var http = require('http');

var handleRequest = function(request, response) {
  console.log('Received request for URL: ' + request.url);
  response.writeHead(200);
  response.end('Hello World!');
};
var www = http.createServer(handleRequest);
www.listen(8080);
```

2. Creare a Dockerfile

`$ vi Dockerfile`
`$ cat Dockerfile`

```
FROM node:6.14.2
EXPOSE 8080
COPY helloWorld.js .
CMD node helloWorld.js
```


3. Create a new repository on Google Cloud Source Repositories

4. Clone to the new repository

`$ git clone https://source.developers.google.com/p/steam-bee-239111/r/hello-world`

5. Move files to hello-world folder.

`$ mv * hello-world/`

`$ cd hello-world`

6. Push files to the repository

`$ git add .`

`$ git commit -m "Initial"`

`$ git push`

**Hello World - Repository**

![](Images/Repository%20-%20Hello%20World.PNG)


**Configuring the build triggers**

Configure Google Container Builder to build and push Docker images every time we push Git tags to our source repository. Container Builder automatically checks out the source code, builds the Docker image from the Dockerfile in the repository, and pushes that image to Container Registry.

1. In the GCP Console, click Build Triggers in the Container Registry section.
2. Select Cloud Source Repository and click Continue.
3. Select your newly created hello-world repository from the list, and click Continue.
4. Set the following trigger settings as shown in the screenshot.

Build Trigger settings

![](Images/Build%20Trigger%20Config.PNG)

Build Trigger created
![](Images/Build%20Trigger.PNG)



**Build image**

Create the first image using the following steps:

1. Go to source code folder in Cloud Shell.

2. Create a Git tag:

`$ git tag v1.0.0`

3. Push the tag:

`$ git push --tags`

4. In Container Registry, click Build History to check that the build has been triggered. If not, verify the trigger was configured properly in the previous section.

5. Go to Container registry to see the recently build image.

gcr.io/steam-bee-239111/hello-world@sha256:91ff13d01441b2eedf169953cb50f063f923e10730253124d789ce78e3dd0610

![](Images/Hello-World%20Image%20registry.PNG)


**Configuring deployment pipelines**

we need to deploy automatically build images to the Kubernetes cluster.

In the Spinnaker UI

http://35.238.154.244:30145/#/infrastructure

**Create the application**

1. In the Spinnaker UI, click Actions, then click Create Application.

2. In the New Application dialog, enter the following fields:

`Name: helloworld`

`Owner Email: muhammedashfaqmi@gmail.com`

3. Click Create.


**Create a Load Balancer**

1. Click on Load Balancers and click on create Load Balancer

2. Specify the target port and once the load balancer is created, it will look like below;

![](Images/Hello%20World%20Load%20Balancer.PNG)



**Create the deployment pipeline**

Now we create the continuous delivery pipeline. 

1. Create a new pipeline named say “Deploy”.

2. Configure automated trigger

![](Images/Automated%20Trigger.PNG)

3. Click on Add Stage

4. Select "Deploy" as type.

5. Under Deploy Configuration, Click on Add Server Group.

6. Refer screenshots below and Configure Deployment Cluster.

Configure Deployment Cluster - Basic Settings

![](Images/Deploy%20config%20-%20Basic%20Settings.PNG)


Configure Deployment Cluster - Deployment

![](Images/Deploy%20config%20-%20Deployment.PNG)


Configure Deployment Cluster - Load Balancers

![](Images/Deploy%20config%20-%20Load%20Balancers.PNG)


Configure Deployment Cluster - Replicas

![](Images/Deploy%20config%20-%20Auto%20Scaling%20and%20Replicas.PNG)


Configure Deployment Cluster - Container

![](Images/Deploy%20config%20-%20Container%20and%20Ports.PNG)


Configure Deployment Cluster - Probes

![](Images/Deploy%20config%20-%20Container%20Probes.PNG)


7. Once the pipeline is created, "click on Start Manual Execution"

8. Go to Task Status under Details in Pipeline to see the progress.

9. When the status is "Status: SUCCEEDED", go to cloud shell and do the following;

Deployment succeeded.

![](Images/Hello%20World%20Deployment%20Pipeline.PNG)

```
muhammedashfaqmi@cloudshell:~/hello-world (steam-bee-239111)$ kubectl get pods
NAME                                        READY     STATUS             RESTARTS   AGE
cd-jenkins-648d96f6f-zxc4p                  1/1       Running            0          5d
cd-redis-674dd48cff-5gxtr                   1/1       Running            0          5d
cd-spinnaker-clouddriver-78b758c655-mpwv6   1/1       Running            0          5d
cd-spinnaker-deck-5fd7789b79-lxm89          1/1       Running            0          5d
cd-spinnaker-echo-5844f87c88-hf6nd          1/1       Running            0          5d
cd-spinnaker-front50-59b74d8599-swm7w       1/1       Running            0          5d
cd-spinnaker-gate-65c559cc65-mmzt6          1/1       Running            2          5d
cd-spinnaker-igor-587df9745d-lwlbg          1/1       Running            0          5d
cd-spinnaker-orca-5ccccdc455-vdvpr          1/1       Running            1          5d
cd-spinnaker-rosco-65498994fd-gc5rw         1/1       Running            0          5d
cd-upload-build-image-2m5r8                 0/1       Completed          0          5d
cd-upload-run-pipeline-mp7ct                0/1       Completed          0          5d
cd-upload-run-script-kwrxn                  0/1       Completed          0          5d
helloworld-v001-4bdph                       1/1       Running            0          2h
helloworld-v001-65xk6                       1/1       Running            0          2h
```

```
muhammedashfaqmi@cloudshell:~/hello-world (steam-bee-239111)$ kubectl get svc
NAME                                 TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)                       AGE
cd-jenkins                           ClusterIP      10.51.244.183   <none>           8080/TCP                      5d
cd-jenkins-agent                     ClusterIP      10.51.250.229   <none>           50000/TCP                     5d
cd-redis                             ClusterIP      10.51.248.149   <none>           6379/TCP                      5d
cd-spinnaker-clouddriver             ClusterIP      10.51.240.117   <none>           7002/TCP                      5d
cd-spinnaker-deck                    ClusterIP      10.51.241.44    <none>           9000/TCP                      5d
cd-spinnaker-deck-5fd7789b79-lxm89   NodePort       10.51.244.249   <none>           9000:30145/TCP                5d
cd-spinnaker-echo                    ClusterIP      10.51.243.236   <none>           8089/TCP                      5d
cd-spinnaker-front50                 ClusterIP      10.51.252.47    <none>           8080/TCP                      5d
cd-spinnaker-gate                    ClusterIP      10.51.249.70    <none>           8084/TCP                      5d
cd-spinnaker-igor                    ClusterIP      10.51.240.44    <none>           8088/TCP,8080/TCP,50000/TCP   5d
cd-spinnaker-orca                    ClusterIP      10.51.252.144   <none>           8083/TCP                      5d
cd-spinnaker-rosco                   ClusterIP      10.51.240.71    <none>           8087/TCP                      5d
helloworld                           LoadBalancer   10.51.253.175   35.232.81.41     80:32356/TCP                  2h
kubernetes                           ClusterIP      10.51.240.1     <none>           443/TCP                       5d
```

Browse through http://35.232.81.41/ to see the deployed Hello-World Application.

![](Images/Hello%20World.PNG)
