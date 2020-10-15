---
title: "Cloud-native CI/CD with Windows container support of Argo"
image: "/img/thumbnails/k8s-argo-win.png"
bigimg: "/img/cloud.jpg"
tags: [Kubernetes,Containers,Windows,Azure,DevOps]
---

The currently newest generation of CI/CD systems builds upon containers and Kubernetes as a runtime environment and uses Kubernetes resources like Jobs for running the steps of your pipeline. This enables reproducability and autoscaling for your CI/CD infrastructure. 

While there are many CI/CD solutions in the [Landscape](https://landscape.cncf.io/category=continuous-integration-delivery&format=card-mode&grouping=category) of the Cloud Native Computing Foundation (CNCF) only some of them like for example [Argo](https://argoproj.github.io/projects/argo) or [Tekton](https://tekton.dev/) belong to this generation of CI/CD systems. Unfortunately none of the solutions in the CNCF Landscape I looked at had support for using Windows containers within your pipeline, so I implemented it for Argo. Argo is a container-native workflow engine for Kubernetes which allows you to easily orchestrate highly parallel jobs on Kubernetes.

## TL;DR

You need to have [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) and [Helm](https://helm.sh/docs/intro/install/) installed. If you don't have a Kubernetes cluster yet and want to create one with Azure Kubernetes Service (AKS) you also need to install the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?view=azure-cli-latest&tabs=azure-cli) as well as [Terraform](https://www.terraform.io/downloads.html). Alternatively to a managed AKS cluster, you can also set up a custom cluster yourself on Azure or locally like I described in [another blog post]({% post_url 2020-09-01-k8s-windows-rancher %}). Afterwards go through the following steps:

```bash
# Create a Kubernetes cluster with AKS (optional if you already have one)
git clone https://github.com/lippertmarkus/terraform-azurerm-aks-windows.git
cd terraform-azurerm-aks-windows
az login   # log in to your Azure account
terraform init  # initialize terraform
terraform apply -auto-approve  # provision infrastructure
terraform output kube_config > ~/.kube/config  # store the kube config as default (be careful if you already have one!)

# Install Argo into the cluster: allow external access, create RBAC resources for default service account for running workflows
helm repo add argo https://argoproj.github.io/argo-helm
helm install argo argo/argo -n argo --create-namespace --set server.serviceType=LoadBalancer --set workflow.serviceAccount.name=default --set workflow.rbac.create=true
kubectl get svc -n argo  # Get external IP for accessing Argo UI
```

Now open `http://<external-ip>:2746` in your browser and deploy your first hybrid workflow like described [later in this post](#schedule-hybrid-workflows).

## Details

### Windows container support in Argo

Of the new generation CI/CD solutions in the CNCF Landscape I looked at, the effort for adding Windows support seemed to be the lowest for Argo, so I spent some time implementing this feature. I added [initial support](https://github.com/argoproj/argo/pull/2747) and later created [an enhancement](https://github.com/argoproj/argo/pull/3301) to optimize the scalability and reliability. After some testing I also helped to [provide official Docker images for Windows](https://github.com/argoproj/argo/pull/3291). This feature now allows you to run Windows containers within your workflows or CI/CD pipelines and even hybrid workflows with both Linux and Windows containers. More details around the Windows container support can be found in the [documentation](https://argoproj.github.io/argo/windows/) of Argo.

### Creating a mixed Kubernetes cluster

I created Terraform definitions for creating an AKS cluster with both a Linux and Windows node pool. There's also [documentation](https://docs.microsoft.com/de-de/azure/aks/windows-container-cli) on how you would do the same manually with the Azure Cloud Shell. Alternatively to the managed AKS cluster you could also create your own custom Kubernetes cluster with Windows support on Azure or locally like I described in a [previous post]({% post_url 2020-09-01-k8s-windows-rancher %}).

Here's how you can quickly create a managed AKS cluster. You need to install [Git](https://git-scm.com/downloads), the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?view=azure-cli-latest&tabs=azure-cli) and [Terraform](https://www.terraform.io/downloads.html) itself. Use the commands below to clone the Git repository, log in to Azure and provision the cluster if you don't already have one to work with:

```bash
# Create a Kubernetes cluster with AKS (optional if you already have one)
git clone https://github.com/lippertmarkus/terraform-azurerm-aks-windows.git
cd terraform-azurerm-aks-windows
az login   # log in to your Azure account
terraform init  # initialize terraform
terraform apply -auto-approve  # provision infrastructure
terraform output kube_config > ~/.kube/config  # store the kube config as default (be careful if you already have one!)
```

The last step stores the content of the `kube_config` output variable in `~/.kube/config` on Linux or `%userprofile%\.kube\config` on Windows to use it as a default connection for accessing your cluster with `kubectl` and `helm` in the next section.

### Installing Argo in your mixed cluster

The easiest way to install Argo in your cluster is to use the community-maintained [Helm Chart](https://github.com/argoproj/argo-helm/tree/master/charts/argo). After adding Windows support to Argo I contributed to the chart to make sure the components of Argo [automatically get scheduled on Linux nodes](https://github.com/argoproj/argo-helm/pull/403) in a mixed cluster. I also [added parameters](https://github.com/argoproj/argo-helm/pull/402) for automatically creating a service account as well as the needed Role-based Access Control (RBAC) resources allowing to schedule workloads right away without manually configuring them.

For using the chart you need to install [Helm](https://helm.sh/docs/intro/install/) as well as [`kubectl`](https://kubernetes.io/docs/tasks/tools/install-kubectl/). You can then add the community-maintained Helm repository and easily install Argo:

```bash
# Install Argo into the cluster: allow external access, create RBAC resources for default service account for running workflows
helm repo add argo https://argoproj.github.io/argo-helm
helm install argo argo/argo -n argo --create-namespace --set server.serviceType=LoadBalancer --set workflow.serviceAccount.name=default --set workflow.rbac.create=true
kubectl get svc -n argo  # Get external IP for accessing Argo UI
```

I used a `LoadBalancer` service for external access to the Argo UI. For an unmanaged clusters you may want to use ingress instead (`--set server.ingress.enabled=true`, `--set server.ingress.hosts[0]=argo.domain.com`). After a couple of seconds you should be able to access the Argo UI via `http://<external-ip>:2746` (or via the ingress host) to schedule your first hybrid workflow.

## Schedule hybrid workflows

With Argo installed you can now schedule Linux-only, Windows-only and even hybrid workflows. Argo adds a Custom Resource Definition (CRD) to Kubernetes for defining workflows. Those can be created via the [Argo CLI](https://github.com/argoproj/argo/releases), `kubectl` or the Argo UI like described in the following.

Within the UI click on *Submit new workflow*, tick the *YAML* checkbox add paste the following hybrid workflow definition before clicking *Submit*:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: hello-hybrid-
  namespace: default
spec:
  entrypoint: myentry
  templates:
    - name: myentry
      steps:
        - - name: step1
            template: hello-windows
        - - name: step2
            template: hello-linux

    - name: hello-windows
      nodeSelector:
        kubernetes.io/os: windows  # step should run on Windows
      container:
        image: mcr.microsoft.com/windows/nanoserver:1809
        command: ["cmd", "/c"]
        args: ["echo", "Hello from Windows Container!"]

    - name: hello-linux
      nodeSelector:
        kubernetes.io/os: linux  # step should run on Linux
      container:
        image: alpine
        command: [echo]
        args: ["Hello from Linux Container!"]
```

The workflow should be self-explaining. After submitting it, the UI shows you the progress of the workflow as well as the logs and other details:

<div class="center" markdown="1">
  <img class="lazy" alt="Overview of a successful workflow in the Argo UI" data-src="/assets/posts/cloud-native-ci-cd-windows-argo/workflow.png" />
</div>

## There's more

Go ahead and [learn more](https://argoproj.github.io/argo/examples/) about the features of Argo. For example there's also support for cloning repositories, handling artifacts, running daemon containers or sidecards, creating Kubernetes resources, running Docker-in-Docker, using variables, loops, conditionals, volumes and much more. Also have a look at how an [example CI pipeline](https://github.com/argoproj/argo/blob/master/examples/influxdb-ci.yaml) could look like. For automatically running Argo on each check-in you can use the [event API endpoint](https://argoproj.github.io/argo/events/).

Also think about the advantages of such a CI/CD system. You can run highly parallel tasks and e.g. use a whole cluster for running large scale performance tests. You can also automatically scale your cluster when you have high resource needs or scale it down at night when your developers don't need it.