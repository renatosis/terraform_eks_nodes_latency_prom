# Steps to create an EKS cluster using Terraform, having its nodes monitored by prometheus to get latency between them

## Creating Github Repo

Created git repo here: https://github.com/renatosis/terraform_eks_nodes_latency_prom  

## Creating EKS Terraform

Started EKS Terraform cluster here: https://learn.hashicorp.com/tutorials/terraform/eks  

## Upgrading awscli client

brew install awscli  
brew update awscli  
aws configure  

Ive got source terraform code from here: git clone https://github.com/hashicorp/learn-terraform-provision-eks-cluster  
cp ../learn-terraform-provision-eks-cluster/*.yaml .  

terraform init  
brew upgrade terraform  
terraform init  

## Provisioning EKS on AWS

terraform apply  

## Configuring Kube config
aws eks --region sa-east-1 update-kubeconfig --name training-eks-WxQJBB2S  

alias k='kubectl'  

k get nodes  
NAME                                       STATUS   ROLES    AGE     VERSION  
ip-10-0-1-196.sa-east-1.compute.internal   Ready    <none>   3m26s   v1.16.13-eks-2ba888  
ip-10-0-3-181.sa-east-1.compute.internal   Ready    <none>   3m24s   v1.16.13-eks-2ba888  
ip-10-0-3-195.sa-east-1.compute.internal   Ready    <none>   3m16s   v1.16.13-eks-2ba888  

## Creating prometheus kube yamls

Created all kube yaml files into kube folder manually and some were based on this: https://phoenixnap.com/kb/prometheus-kubernetes-monitoring#:~:text=Prometheus%20monitoring%20can%20be%20installed,the%20elements%20of%20your%20cluster.  

Ive got kube prometheus default config yaml from here: https://github.com/prometheus/prometheus/blob/master/documentation/examples/prometheus-kubernetes.yml  

## Applying kube yamls

k apply -f prometheus-namespace.yaml  
k apply -f prometheus-sa.yaml -f prometheus-clusterrole.yaml -f prometheus-clusterrole-binding.yaml  
k apply -f prometheus-cm.yaml  
k apply -f prometheus-deployment.yaml  
k apply -f prometheus-service.yaml  

## Accessing prometheus dashboard

k get svc -n prometheus  
NAME         TYPE           CLUSTER-IP      EXTERNAL-IP                                                               PORT(S)          AGE  
prometheus   LoadBalancer   172.20.120.78   affce3af522d947ac8ce769362bc6689-1556436982.sa-east-1.elb.amazonaws.com   9090:30909/TCP   3m31s  

curl http://affce3af522d947ac8ce769362bc6689-1556436982.sa-east-1.elb.amazonaws.com:9090  
<a href="/graph">Found</a>.  

## See if prometheus targets are being scrapped sucessfully
curl http://affce3af522d947ac8ce769362bc6689-1556436982.sa-east-1.elb.amazonaws.com:9090/targets  

## Search on google for a network analyzer for latency checks between nodes

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
 
## Creating ping-exporter docker image:
docker build -t renatosis/ping-exporter .  
docker login  
docker push renatosis/ping-exporter  

## Creating ping-exporter resources on minikube

minikube node add --worker=true
k create ns prometheus
k apply -f pingexporter_sa.yaml
k apply -f pingexporter_cm.yaml
k apply -f pingexporter_ds.yaml  

To make  prometheus to work locally I had to apply all the ./kube/*.yaml files  

I had problems make ping-exporter working locally because of how it was planned to get node ips. In order to make it work I had to specify the workers manually on pingexporter_cm.yaml  

## Watching ping-exporter metrics being scrapped from prometheus
kubectl port-forward prometheus-66fb88cb4b-xfqdb 7000:9090 -n prometheus

## Well, It didnt work locally! =( I saw prometheus targets conn refused errors 

## Ive got it working on EKS but I couldnt see metrics from pingexporter, lets debug

Ive changed the minikibe ips endpoints to the EKS endpoints statically first  
{"cluster_targets":[{"ipAddress":"10.0.1.142","name":"kube-1"},{"ipAddress":"10.0.1.147","name":"kube-2"},{"ipAddress":"10.0.3.253","name":"kube-3"}],"external_targets":[{"host":"8.8.8.8","name":"google-dns"},{"host":"youtube.com"}]}  

Lets get in a pod to see that was the file generated after pingexporter lauched  

k get pods -n prometheus  
k exec -it ping-exporter-4ws2k -n prometheus -- sh  

I saw that the files required for node exporter were being created by pingexporter on /node-exporter-textfile/ping-exporter_ip-10-0-3-253.sa-east-1.compute.internal.prom   
But somehow node exporter running on the host machine wasnt using it. Why?  
I had to create a bastion to manage this problem and debug it  

I had to modify all worker node groups to add my key to be able to get inside the node. I had to reapply terraform and terminate all instances to make autoscale group readd them  
After the recreation I could ssh-in to the bastion created manually (because via terraform wasnt working dont know why) and ssh-into one of the workers. Ive noticed that there was no nodeexporter running, so I must create an NodeExporter DS and make prometheus watch it.  

Ive got NodeExporter yaml here: https://coreos.com/blog/prometheus-and-kubernetes-up-and-running.html#:~:text=The%20node%20exporter%20can%20read,node%20exporter%20as%20a%20service.  

The yaml got from the link above from CoreOS were not adapted to the kubernetes version I was using, so I had to change some configs in order to make it work. Theres an example of error:  

k apply -f node-exporter.yaml  
service/node-exporter unchanged  
The DaemonSet "node-exporter" is invalid: spec.template.metadata.labels: Invalid value: map[string]string(nil): `selector` does not match template `labels`  

After fixing it it was working:  
k get pods -A | grep node-ex  
default       node-exporter-k8z28           1/1     Running   0          96s  
default       node-exporter-l9hkr           1/1     Running   0          96s  
default       node-exporter-vg4sd           1/1     Running   0          96s  

PingExporter was exporting its metrics to /node-exporter-textfile/ which is a mount directory on host /var/run/node-exporter-textfile and we have to make it available on node-exporter  

After changing the NodeExporter DS to mount a host dir it was possible to see prom files required to nodexporter to export it to prometheus.  
Prometheus was default configured to get metrics from all its services on /metrics URN, so it was able to get metrics from nodeexporter/pingexporter  

## Getting results from prometheus

kubectl port-forward prometheus-55968449bd-dkccf 9090:9090 -n prometheus &  

After prometheus scrap I could see all latency from all nodes to all nodes:

http://localhost:9090/graph?g0.range_input=1h&g0.expr=kube_node_ping_rtt_milliseconds_total&g0.tab=1  

Element	Value
kube_node_ping_rtt_milliseconds_total{controller_revision_hash="75694cb8c8",destination_node="kube-1-a",destination_node_ip_address="10.0.1.107",instance="10.0.1.107:9100",job="kubernetes-pods",kubernetes_namespace="default",kubernetes_pod_name="node-exporter-pxzk9",name="node-exporter",pod_template_generation="1"}	136.38000000000008  
kube_node_ping_rtt_milliseconds_total{controller_revision_hash="75694cb8c8",destination_node="kube-1-a",destination_node_ip_address="10.0.1.107",instance="10.0.3.115:9100",job="kubernetes-pods",kubernetes_namespace="default",kubernetes_pod_name="node-exporter-9ctrj",name="node-exporter",pod_template_generation="1"}	3349.5800000000004  
kube_node_ping_rtt_milliseconds_total{controller_revision_hash="75694cb8c8",destination_node="kube-1-a",destination_node_ip_address="10.0.1.107",instance="10.0.3.205:9100",job="kubernetes-pods",kubernetes_namespace="default",kubernetes_pod_name="node-exporter-bqk2g",name="node-exporter",pod_template_generation="1"}	5494.629999999999  
kube_node_ping_rtt_milliseconds_total{controller_revision_hash="75694cb8c8",destination_node="kube-1-c",destination_node_ip_address="10.0.3.115",instance="10.0.1.107:9100",job="kubernetes-pods",kubernetes_namespace="default",kubernetes_pod_name="node-exporter-pxzk9",name="node-exporter",pod_template_generation="1"}	3414.789999999999  
kube_node_ping_rtt_milliseconds_total{controller_revision_hash="75694cb8c8",destination_node="kube-1-c",destination_node_ip_address="10.0.3.115",instance="10.0.3.115:9100",job="kubernetes-pods",kubernetes_namespace="default",kubernetes_pod_name="node-exporter-9ctrj",name="node-exporter",pod_template_generation="1"}	83.64000000000004  
kube_node_ping_rtt_milliseconds_total{controller_revision_hash="75694cb8c8",destination_node="kube-1-c",destination_node_ip_address="10.0.3.115",instance="10.0.3.205:9100",job="kubernetes-pods",kubernetes_namespace="default",kubernetes_pod_name="node-exporter-bqk2g",name="node-exporter",pod_template_generation="1"}	2901.7299999999996  
kube_node_ping_rtt_milliseconds_total{controller_revision_hash="75694cb8c8",destination_node="kube-2-c",destination_node_ip_address="10.0.3.205",instance="10.0.1.107:9100",job="kubernetes-pods",kubernetes_namespace="default",kubernetes_pod_name="node-exporter-pxzk9",name="node-exporter",pod_template_generation="1"}	5253.669999999999  
kube_node_ping_rtt_milliseconds_total{controller_revision_hash="75694cb8c8",destination_node="kube-2-c",destination_node_ip_address="10.0.3.205",instance="10.0.3.115:9100",job="kubernetes-pods",kubernetes_namespace="default",kubernetes_pod_name="node-exporter-9ctrj",name="node-exporter",pod_template_generation="1"}	2263.1900000000005
kube_node_ping_rtt_milliseconds_total{controller_revision_hash="75694cb8c8",destination_node="kube-2-c",destination_node_ip_address="10.0.3.205",instance="10.0.3.205:9100",job="kubernetes-pods",kubernetes_namespace="default",kubernetes_pod_name="node-exporter-bqk2g",name="node-exporter",pod_template_generation="1"}	162.8300000000001  

Its possible to see that locally the latency is so low and to the other onde on the same zone has a medium latency. But the latency to the vm on the other zone is huge!  