# Creating Github Repo

Created git repo here: https://github.com/renatosis/terraform_eks_nodes_latency_prom  

# Creating EKS Terraform

Started EKS Terraform cluster here: https://learn.hashicorp.com/tutorials/terraform/eks  

# Upgrading awscli client

brew install awscli  
brew update awscli  
aws configure  

Ive got source terraform code from here: git clone https://github.com/hashicorp/learn-terraform-provision-eks-cluster  
cp ../learn-terraform-provision-eks-cluster/*.yaml .  

terraform init  
brew upgrade terraform  
terraform init  

# Provisioning EKS on AWS

terraform apply  

# Configuring Kube config
aws eks --region sa-east-1 update-kubeconfig --name training-eks-WxQJBB2S  

alias k='kubectl'  

k get nodes  
NAME                                       STATUS   ROLES    AGE     VERSION  
ip-10-0-1-196.sa-east-1.compute.internal   Ready    <none>   3m26s   v1.16.13-eks-2ba888  
ip-10-0-3-181.sa-east-1.compute.internal   Ready    <none>   3m24s   v1.16.13-eks-2ba888  
ip-10-0-3-195.sa-east-1.compute.internal   Ready    <none>   3m16s   v1.16.13-eks-2ba888  

# Creating prometheus kube yamls

Created all kube yaml files into kube folder manually and some were based on this: https://phoenixnap.com/kb/prometheus-kubernetes-monitoring#:~:text=Prometheus%20monitoring%20can%20be%20installed,the%20elements%20of%20your%20cluster.  

Ive got kube prometheus default config yaml from here: https://github.com/prometheus/prometheus/blob/master/documentation/examples/prometheus-kubernetes.yml  

# Applying kube yamls

k apply -f prometheus-namespace.yaml  
k apply -f prometheus-sa.yaml -f prometheus-clusterrole.yaml -f prometheus-clusterrole-binding.yaml  
k apply -f prometheus-cm.yaml  
k apply -f prometheus-deployment.yaml  
k apply -f prometheus-service.yaml  

# Accessing prometheus dashboard

k get svc -n prometheus  
NAME         TYPE           CLUSTER-IP      EXTERNAL-IP                                                               PORT(S)          AGE  
prometheus   LoadBalancer   172.20.120.78   affce3af522d947ac8ce769362bc6689-1556436982.sa-east-1.elb.amazonaws.com   9090:30909/TCP   3m31s  

curl http://affce3af522d947ac8ce769362bc6689-1556436982.sa-east-1.elb.amazonaws.com:9090  
<a href="/graph">Found</a>.  

# See if prometheus targets are being scrapped sucessfully
curl http://affce3af522d947ac8ce769362bc6689-1556436982.sa-east-1.elb.amazonaws.com:9090/targets  

# Search on google for a network analyzer for latency checks between nodes

Tried to find a docker image with a network analyzer but insted, Ive found almost the entire solution here: https://medium.com/flant-com/ping-monitoring-between-kubernetes-nodes-11e815f4eff1  

First I had to problems creating a Dockerfile due to missing requirements.txt libs so I had to build Dockerfile and test which libs were missing just by running the script:

docker build -t teste .  
docker run -it teste sh  

export MY_NODE_NAME=node1  
export PROMETHEUS_TEXTFILE_DIR=dir  
export PROMETHEUS_TEXTFILE_PREFIX=prefix  
python3 ping-exporter.py  

To test it locally before starting EKS I had to run minikube with:  
brew install minikube  
minikube start  
 
# Creating ping-exporter docker image:
docker build -t renatosis/ping-exporter .  
docker login  
docker push renatosis/ping-exporter  

# Creating ping-exporter resources on minikube

minikube node add --worker=true
k create ns prometheus
k apply -f pingexporter_sa.yaml
k apply -f pingexporter_cm.yaml
k apply -f pingexporter_ds.yaml  

To make  prometheus to work locally I had to apply all the ./kube/*.yaml files  

I had problems make ping-exporter working locally because of how it was planned to get node ips. In order to make it work I had to specify the workers manually on pingexporter_cm.yaml  

# Watching ping-exporter metrics being scrapped from prometheus
kubectl port-forward prometheus-66fb88cb4b-xfqdb 7000:9090 -n prometheus

# Well, It didnt work locally! =( I saw prometheus targets conn refused errors 
# Ill try tomorrow