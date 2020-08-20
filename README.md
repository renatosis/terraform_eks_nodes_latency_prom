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

# Next step is to create a network analizer on each node and scrap their data
