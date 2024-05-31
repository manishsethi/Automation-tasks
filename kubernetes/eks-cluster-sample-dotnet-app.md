# Running an Amazon EKS Cluster with Fargate and Deploying a .NET Application Image from ECR

## Prerequisites

1. **AWS CLI**: Ensure AWS CLI is installed and configured with the necessary permissions.
2. **kubectl**: Install kubectl to interact with your EKS cluster.
3. **eksctl**: Install eksctl to create and manage EKS clusters.
4. **Docker**: Ensure Docker is installed and configured.

## Step-by-Step Guide

### Step 1: Create an EKS Cluster with Fargate

1. **Install AWS CLI, kubectl, and eksctl:**

    ```sh
    # AWS CLI
    curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
    sudo installer -pkg AWSCLIV2.pkg -target /

    # kubectl
    curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.21.2/2021-07-05/bin/darwin/amd64/kubectl
    chmod +x ./kubectl
    sudo mv ./kubectl /usr/local/bin

    # eksctl
    curl --location "https://github.com/weaveworks/eksctl/releases/download/0.78.0/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    sudo mv /tmp/eksctl /usr/local/bin
    ```

2. **Create an EKS Cluster with Fargate:**

    ```sh
    eksctl create cluster \
      --name demo-cluster \
      --region us-west-2 \
      --fargate
    ```

### Step 2: Create a Fargate Profile

1. **Create a Fargate Profile:**

    ```sh
    eksctl create fargateprofile \
      --cluster demo-cluster \
      --name my-fargate-profile \
      --namespace hello-world
    ```

Once the cluster is created, proceed to application deployment.

### Step 3: Configure IAM OIDC Provider

```sh
export cluster_name=demo-cluster
oidc_id=$(aws eks describe-cluster --name $cluster_name --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
eksctl utils associate-iam-oidc-provider --cluster $cluster_name --approve
```

### Step 4: Configure and Deploy Your Application

#### Create a `full.yaml` with the Following Content

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: helloworld
---
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: helloworld
  name: deployment-helloworld
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: app-helloworld
  replicas: 2
  template:
    metadata:
      labels:
        app.kubernetes.io/name: app-helloworld
    spec:
      containers:
      - image: mcr.microsoft.com/dotnet/samples:aspnetapp # change this to ECR image
        imagePullPolicy: Always
        name: app-helloworld
        ports:
        - containerPort: 8080 
---
apiVersion: v1
kind: Service
metadata:
  namespace: helloworld
  name: service-helloworld
spec:
  ports:
    - port: 80
      targetPort: 8080
      protocol: TCP
  type: NodePort
  selector:
    app.kubernetes.io/name: app-helloworld
---
```
#### Apply Your Changes and Verify the Status

```sh
    kubectl apply -f full.yaml
    kubectl get all -n helloworld
```


### Step 5: Deploy ALB Controller

#### Download IAM Policy

```sh
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.5.4/docs/install/iam_policy.json
```

#### Create IAM Policy

```sh
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

```
#### Create IAM Role

```sh
eksctl create iamserviceaccount \
  --cluster=demo-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::975049935206:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve
```

#### Deploy ALB Controller
##### Add Helm Repo

```sh
helm repo add eks https://aws.github.io/eks-charts
```

##### Update the Repo

```sh
helm repo update eks
```

##### Install

```sh
helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system \
  --set clusterName=demo-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=us-west-2 \
  --set vpcId=vpc-0fb79824e947be474
```

##### Verify That the Deployments Are Running

```sh
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get all -n kube-system
```


That's it. Your application should be accessible. To check the ALB URL, use the command below:

```sh
$ kubectl get ingress -n helloworld
```

