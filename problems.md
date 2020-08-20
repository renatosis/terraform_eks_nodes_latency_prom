when running terraform apply Ive got:

dyld: Library not loaded: @executable_path/../.Python
  Referenced from: /usr/local/aws/bin/python
  Reason: image not found
Abort trap: 6

brew upgrade awscli didnt solve

After reapplying terraform got:

"data.aws_availability_zones.available: Reading... [id=2020-08-19 21:52:38.998256 +0000 UTC]
data.aws_availability_zones.available: Read complete after 0s [id=2020-08-19 21:52:47.001727 +0000 UTC]

Error: Provider produced inconsistent final plan"

It was because of wget:
wget
dyld: Library not loaded: /usr/local/opt/openssl/lib/libssl.1.0.0.dylib
  Referenced from: /usr/local/bin/wget
  Reason: image not found
Abort trap: 6

brew upgrade wget solved it!

Got this error when applying kube prometheus deploykent:

k apply -f prometheus-deployment.yaml
error: unable to recognize "prometheus-deployment.yaml": no matches for kind "Deployment" in version "apps/v1beta2"

EKS default cluster was created based on version 1.16
In order to fix I had to see what was the version supported for apps:
kubectl api-versions | grep apps
apps/v1