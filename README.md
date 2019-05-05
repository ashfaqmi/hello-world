# hello-world
Blue Green deployment of nodeJS app on Google Kubenetes engine using Spinnaker and Helm


**Enable the APIs needed on GCP**

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

Screenshots ------------
Cluster and Nodes --------

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

Screenshot - Spinnaker



**Building the container image**\



