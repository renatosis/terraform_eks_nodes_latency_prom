# Steps to create an EKS cluster using Terraform, having its nodes monitored by prometheus to get latency between them

## Creating Github Repo

Created git repo here: https://github.com/renatosis/terraform_eks_nodes_latency_prom  

## Creating EKS Terraform

Started EKS Terraform cluster here: https://learn.hashicorp.com/tutorials/terraform/eks  

## Upgrading awscli client

```
brew install awscli  
brew update awscli  
aws configure  
```

Ive got source terraform code from here: git clone https://github.com/hashicorp/learn-terraform-provision-eks-cluster  

```
cp ../learn-terraform-provision-eks-cluster/*.yaml .  
terraform init  
brew upgrade terraform  
terraform init  
```

## Provisioning EKS on AWS

```
terraform apply  
```

## Configuring Kube config
```
aws eks --region sa-east-1 update-kubeconfig --name training-eks-WxQJBB2S  

alias k='kubectl'  

k get nodes  
NAME                                       STATUS   ROLES    AGE     VERSION  
ip-10-0-1-196.sa-east-1.compute.internal   Ready    <none>   3m26s   v1.16.13-eks-2ba888  
ip-10-0-3-181.sa-east-1.compute.internal   Ready    <none>   3m24s   v1.16.13-eks-2ba888  
ip-10-0-3-195.sa-east-1.compute.internal   Ready    <none>   3m16s   v1.16.13-eks-2ba888  
```

## Creating prometheus kube yamls

Created all kube yaml files into kube folder manually and some were based on this: https://phoenixnap.com/kb/prometheus-kubernetes-monitoring#:~:text=Prometheus%20monitoring%20can%20be%20installed,the%20elements%20of%20your%20cluster.  

Ive got kube prometheus default config yaml from here: https://github.com/prometheus/prometheus/blob/master/documentation/examples/prometheus-kubernetes.yml  

## Applying kube yamls

```
k apply -f prometheus-namespace.yaml  
k apply -f prometheus-sa.yaml -f prometheus-clusterrole.yaml -f prometheus-clusterrole-binding.yaml  
k apply -f prometheus-cm.yaml  
k apply -f prometheus-deployment.yaml  
k apply -f prometheus-service.yaml  
```

## Accessing prometheus dashboard

```
k get svc -n prometheus  
NAME         TYPE           CLUSTER-IP      EXTERNAL-IP                                                               PORT(S)          AGE  
prometheus   LoadBalancer   172.20.120.78   affce3af522d947ac8ce769362bc6689-1556436982.sa-east-1.elb.amazonaws.com   9090:30909/TCP   3m31s  

curl http://affce3af522d947ac8ce769362bc6689-1556436982.sa-east-1.elb.amazonaws.com:9090  
<a href="/graph">Found</a>.  
```

## See if prometheus targets are being scrapped sucessfully
```
curl http://affce3af522d947ac8ce769362bc6689-1556436982.sa-east-1.elb.amazonaws.com:9090/targets  
```

## Search on google for a network analyzer for latency checks between nodes

Tried to find a docker image with a network analyzer but insted, Ive found almost the entire solution here: https://medium.com/flant-com/ping-monitoring-between-kubernetes-nodes-11e815f4eff1  

First I had to problems creating a Dockerfile due to missing requirements.txt libs so I had to build Dockerfile and test which libs were missing just by running the script:

```
docker build -t teste .  
docker run -it teste sh  

export MY_NODE_NAME=node1  
export PROMETHEUS_TEXTFILE_DIR=dir  
export PROMETHEUS_TEXTFILE_PREFIX=prefix  
python3 ping-exporter.py  
```

To test it locally before starting EKS I had to run minikube with:  
```
brew install minikube  
minikube start  
```
 
## Creating ping-exporter docker image:
```
docker build -t renatosis/ping-exporter .  
docker login  
docker push renatosis/ping-exporter  
```

## Creating ping-exporter resources on minikube

```
minikube node add --worker=true
k create ns prometheus
k apply -f pingexporter_sa.yaml
k apply -f pingexporter_cm.yaml
k apply -f pingexporter_ds.yaml  
```

To make  prometheus to work locally I had to apply all the ./kube/*.yaml files  

I had problems make ping-exporter working locally because of how it was planned to get node ips. In order to make it work I had to specify the workers manually on pingexporter_cm.yaml  

## Watching ping-exporter metrics being scrapped from prometheus
```
kubectl port-forward prometheus-66fb88cb4b-xfqdb 7000:9090 -n prometheus
```

## Well, It didnt work locally! =( I saw prometheus targets conn refused errors 

## Ive got it working on EKS but I couldnt see metrics from pingexporter, lets debug

Ive changed the minikibe ips endpoints to the EKS endpoints statically first 
``` 
{"cluster_targets":[{"ipAddress":"10.0.1.142","name":"kube-1"},{"ipAddress":"10.0.1.147","name":"kube-2"},{"ipAddress":"10.0.3.253","name":"kube-3"}],"external_targets":[{"host":"8.8.8.8","name":"google-dns"},{"host":"youtube.com"}]}  
```

Lets get in a pod to see that was the file generated after pingexporter lauched  

```
k get pods -n prometheus  
k exec -it ping-exporter-4ws2k -n prometheus -- sh
```  

I saw that the files required for node exporter were being created by pingexporter on /node-exporter-textfile/ping-exporter_ip-10-0-3-253.sa-east-1.compute.internal.prom   
But somehow node exporter running on the host machine wasnt using it. Why?  
I had to create a bastion to manage this problem and debug it  

I had to modify all worker node groups to add my key to be able to get inside the node. I had to reapply terraform and terminate all instances to make autoscale group readd them  
After the recreation I could ssh-in to the bastion created manually (because via terraform wasnt working dont know why) and ssh-into one of the workers. Ive noticed that there was no nodeexporter running, so I must create an NodeExporter DS and make prometheus watch it.  

Ive got NodeExporter yaml here: https://coreos.com/blog/prometheus-and-kubernetes-up-and-running.html#:~:text=The%20node%20exporter%20can%20read,node%20exporter%20as%20a%20service.  

The yaml got from the link above from CoreOS were not adapted to the kubernetes version I was using, so I had to change some configs in order to make it work. Theres an example of error:  

```
k apply -f node-exporter.yaml  
service/node-exporter unchanged  
The DaemonSet "node-exporter" is invalid: spec.template.metadata.labels: Invalid value: map[string]string(nil): `selector` does not match template `labels`  
```

After fixing it it was working:  

```
k get pods -A | grep node-ex  
default       node-exporter-k8z28           1/1     Running   0          96s  
default       node-exporter-l9hkr           1/1     Running   0          96s  
default       node-exporter-vg4sd           1/1     Running   0          96s  
```

PingExporter was exporting its metrics to /node-exporter-textfile/ which is a mount directory on host /var/run/node-exporter-textfile and we have to make it available on node-exporter  

After changing the NodeExporter DS to mount a host dir it was possible to see prom files required to nodexporter to export it to prometheus.  
Prometheus was default configured to get metrics from all its services on /metrics URN, so it was able to get metrics from nodeexporter/pingexporter  

## Getting results from prometheus

```
kubectl port-forward prometheus-55968449bd-dkccf 9090:9090 -n prometheus &  
```

After prometheus scrap I could see all latency from all nodes to all nodes:

```
http://localhost:9090/graph?g0.range_input=1h&g0.expr=kube_node_ping_rtt_milliseconds_total&g0.tab=1  

Element	Value
kube_node_ping_rtt_milliseconds_total{controller_revision_hash="75694cb8c8",destination_node="10.0.1.122-1a",destination_node_ip_address="10.0.1.122",instance="10.0.1.122:9100",job="kubernetes-pods",kubernetes_namespace="default",kubernetes_pod_name="node-exporter-4grdd",name="node-exporter",pod_template_generation="1"}	8.690000000000005
kube_node_ping_rtt_milliseconds_total{controller_revision_hash="75694cb8c8",destination_node="10.0.1.122-1a",destination_node_ip_address="10.0.1.122",instance="10.0.1.165:9100",job="kubernetes-pods",kubernetes_namespace="default",kubernetes_pod_name="node-exporter-4bqlh",name="node-exporter",pod_template_generation="1"}	75.80000000000001
kube_node_ping_rtt_milliseconds_total{controller_revision_hash="75694cb8c8",destination_node="10.0.1.122-1a",destination_node_ip_address="10.0.1.122",instance="10.0.3.229:9100",job="kubernetes-pods",kubernetes_namespace="default",kubernetes_pod_name="node-exporter-tptb6",name="node-exporter",pod_template_generation="1"}	150.35999999999999
kube_node_ping_rtt_milliseconds_total{controller_revision_hash="75694cb8c8",destination_node="10.0.1.165-1a",destination_node_ip_address="10.0.1.165",instance="10.0.1.122:9100",job="kubernetes-pods",kubernetes_namespace="default",kubernetes_pod_name="node-exporter-4grdd",name="node-exporter",pod_template_generation="1"}	74.83000000000001
kube_node_ping_rtt_milliseconds_total{controller_revision_hash="75694cb8c8",destination_node="10.0.1.165-1a",destination_node_ip_address="10.0.1.165",instance="10.0.1.165:9100",job="kubernetes-pods",kubernetes_namespace="default",kubernetes_pod_name="node-exporter-4bqlh",name="node-exporter",pod_template_generation="1"}	5.430000000000002
kube_node_ping_rtt_milliseconds_total{controller_revision_hash="75694cb8c8",destination_node="10.0.1.165-1a",destination_node_ip_address="10.0.1.165",instance="10.0.3.229:9100",job="kubernetes-pods",kubernetes_namespace="default",kubernetes_pod_name="node-exporter-tptb6",name="node-exporter",pod_template_generation="1"}	139.39999999999998
kube_node_ping_rtt_milliseconds_total{controller_revision_hash="75694cb8c8",destination_node="10.0.3.229-1c",destination_node_ip_address="10.0.3.229",instance="10.0.1.122:9100",job="kubernetes-pods",kubernetes_namespace="default",kubernetes_pod_name="node-exporter-4grdd",name="node-exporter",pod_template_generation="1"}	183.32
kube_node_ping_rtt_milliseconds_total{controller_revision_hash="75694cb8c8",destination_node="10.0.3.229-1c",destination_node_ip_address="10.0.3.229",instance="10.0.1.165:9100",job="kubernetes-pods",kubernetes_namespace="default",kubernetes_pod_name="node-exporter-4bqlh",name="node-exporter",pod_template_generation="1"}	180.06
kube_node_ping_rtt_milliseconds_total{controller_revision_hash="75694cb8c8",destination_node="10.0.3.229-1c",destination_node_ip_address="10.0.3.229",instance="10.0.3.229:9100",job="kubernetes-pods",kubernetes_namespace="default",kubernetes_pod_name="node-exporter-tptb6",name="node-exporter",pod_template_generation="1"}	3.760000000000002  
```

Its possible to see that locally the latency is so low and to the other onde on the same zone has a medium latency. But the latency to the vm on the other zone is huge!  

![Results](https://github.com/renatosis/terraform_eks_nodes_latency_prom/blob/master/result.png "Results")

## Recreating all kube yamls from yaml to kubernetes terraform provision format

After recreating all kube yaml files in terraform kubernetes provision way I noticed a prometheus deployment timeout. I run terraform output to get the kube eks config to be able to run kube debug commands  
There was an error running the pod: 
```
k logs prometheus-d78bfcf77-rkbj8 -n prometheus
level=error ts=2020-09-19T20:22:16.377Z caller=main.go:283 msg="Error loading config (--config.file=/etc/prometheus/prometheus.yml)" err="parsing YAML file /etc/prometheus/prometheus.yml: yaml: unmarshal errors:\n  line 1: cannot unmarshal !!str `./confi...` into config.plain"
```

I also had to limit the timeout which was 10min in the prometheus deployment config: 
```
timeouts {
    create = "1m"
  }
```

I noticed that I wasnt using file to get prometheus.yaml locally.  
After that all of the service discovery targets were 0. 

Running 
```
k logs -f prometheus-d78bfcf77-vpwk6
level=error ts=2020-09-19T20:55:45.273Z caller=manager.go:344 component="discovery manager scrape" msg="Cannot create service discovery" err="open /var/run/secrets/kubernetes.io/serviceaccount/token: no such file or directory" type=*kubernetes.SDConfig
```
I was able to see what was the problem  

Then I discovered that there was an option `automount_service_account_token` which was false on the prometheus deployment. I've turned it on configuring `automount_service_account_token = true` and destroying and applying the terraform again.  
After That I was able to see all of the scraps happening again  
Now its time to make the kconmon to monitor node latencies.  

## Making kconmon work on our kubernetes cluster


