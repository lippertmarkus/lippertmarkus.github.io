---
title: "Easily deploy Business Central to Kubernetes with Helm"
image: "/img/thumbnails/k8s-win-bc.png"
bigimg: "/img/bc-k8s.jpg"
tags: [Kubernetes,Containers,Windows,Azure,Business Central,DevOps]
---

Running the ERP system Microsoft Dynamics 365 Business Central is facilitated through Docker and [the official images](https://github.com/microsoft/nav-docker/) Microsoft provides. Taking this one step further and deploying Business Central to a cluster can be challenging however. I recently did a [small survey](https://forms.microsoft.com/Pages/AnalysisPage.aspx?id=DQSIkWdsW0yxEjajBLZtrQAAAAAAAAAAAAMAAK03qWdUOTNKU1JSRUNMVkVSQ1NSWEFNRzYzRTFGSS4u&AnalyzerToken=xuLooFWnazmZIokaZcqqVBC2m0CeCTwY) and found it interesting that using Container orchestration for Business Central seems to be an exception. Container orchestrators like Kubernetes provide additional benefits like scalability and high availability but also introduce new complexity. To overcome some of this complexity, [Helm](https://helm.sh/) simplifies the installation of applications. Leveraging this, I created a [Helm chart for Business Central](https://artifacthub.io/packages/helm/lippertmarkus/business-central) with the goal to simplify the deployment of Business Central within a cluster.

## TL;DR

You need to have [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) and [Helm](https://helm.sh/docs/intro/install/) installed. If you don't have a Kubernetes cluster yet and want to create one with Azure Kubernetes Service (AKS) you also need to install the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?view=azure-cli-latest&tabs=azure-cli) as well as [Terraform](https://www.terraform.io/downloads.html). Alternatively to a managed AKS cluster, you can also set up a custom cluster yourself on Azure or on-premises like I described in [another blog post]({% post_url 2020-09-01-k8s-windows-rancher %}).

```powershell
# Create a Kubernetes cluster with AKS (optional if you already have one)
git clone https://github.com/lippertmarkus/terraform-azurerm-aks-windows.git
cd terraform-azurerm-aks-windows
az login   # log in to your Azure account
terraform init  # initialize terraform
terraform apply -auto-approve  # provision infrastructure
terraform output kube_config > ~/.kube/config  # store the kube config as default (be careful if you already have one!)

# Install the Business Central Helm chart into the cluster
helm repo add lippertmarkus https://charts.lippertmarkus.com
helm install bc1 lippertmarkus/business-central --set service.type=LoadBalancer
```

Now have a look at how to use the chart with some [common scenarios](#scenarios).

## Details

[Kubernetes](https://kubernetes.io) is a container orchestration system which makes deploying and managing containerized applications easy. Kubernetes itself uses multiple YAML files to define all resources an application needs. [Helm](https://helm.sh) is currently the de-facto package manager for Kubernetes and makes the installation and management of applications easy. It bundles Kubernetes resources within a Helm Chart. 

[Terraform](https://www.terraform.io/) allows you to define infrastructure as code to fully automate the management of infrastructure with different cloud providers as well as services.

### Creating a mixed Kubernetes cluster

I'm using Terraform for creating an AKS cluster with both a Linux and Windows node pool. There's also [documentation](https://docs.microsoft.com/de-de/azure/aks/windows-container-cli) on how you would do the same manually with the Azure Cloud Shell. Alternatively to the managed AKS cluster you could also create your own custom Kubernetes cluster with Windows support on Azure or on-premises like I described in a [previous post]({% post_url 2020-09-01-k8s-windows-rancher %}).

However, using a managed AKS cluster is the easiest and quickest solutions. You need to install [Git](https://git-scm.com/downloads), the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?view=azure-cli-latest&tabs=azure-cli) and [Terraform](https://www.terraform.io/downloads.html) itself. Use the commands below to clone the Git repository, log in to Azure and provision the cluster if you don't already have one to work with:

```powershell
# Create a Kubernetes cluster with AKS (optional if you already have one)
git clone https://github.com/lippertmarkus/terraform-azurerm-aks-windows.git
cd terraform-azurerm-aks-windows
az login   # log in to your Azure account
terraform init  # initialize terraform
terraform apply -auto-approve  # provision infrastructure
terraform output kube_config > ~/.kube/config  # store the kube config as default (be careful if you already have one!)
```

The last step stores the content of the `kube_config` output variable in `~/.kube/config` on Linux or `%userprofile%\.kube\config` on Windows to use it as a default connection for accessing your cluster with `kubectl` and `helm` in the next section.

### Deploying Business Central in your cluster

To get started install [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) and [Helm](https://helm.sh/docs/intro/install/) first. To later be able to access Business Central, you have [multiple options](https://artifacthub.io/packages/helm/lippertmarkus/business-central#accessing-business-central). Directly assigning a public IP to the Business Central environment through a load balancer is the easiest option if you're using a managed Kubernetes cluster like AKS:
```powershell
# Install Business Central and get external IP
helm repo add lippertmarkus https://charts.lippertmarkus.com
helm install bc1 lippertmarkus/business-central --set service.type=LoadBalancer
# you may need to wait a few seconds before the extern IP is available before running the next command
$ip=$(kubectl get svc bc1-business-central --template "{% raw %}{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}{% endraw %}")

# Get the generated password like shown after installation
$pw=$(kubectl get secret/bc1-business-central --template="{% raw %}{{.data.password}}{% endraw %}")
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($pw))
# Wait until "Successfully pulled image..." and "Started container business-central"
kubectl describe pods -l "app.kubernetes.io/instance=bc1"
# Follow the startup logs, hit Ctrl + C if startup is successful
kubectl logs -f deployment/bc1-business-central
start "http://$ip/BC"  # open browser
```

For on-premises or when having multiple environments you may want to [use Ingress](https://artifacthub.io/packages/helm/lippertmarkus/business-central#accessing-business-central) instead. 

The startup takes fairly long as the Business Central artifacts get downloaded and installed at startup. Let's see what other possibilities we have.

## Scenarios

While the Helm chart for Business Central already makes deployment more easy it also simplifies some common scenarios through the exposed configuration options like:

- **Using artifacts and pre-built images**: You can either use a generic Business Central image and specify the artifact URL for the version you want to automatically set up on startup or build your own specific Business Central image and reference that.
- **Securing your passwords**: The chart stores your passwords as well as the password key file securely in a Kubernetes secret and sets them up accordingly to be used by the Business Central image.
- **Modifying default behavior**: Overwriting the default behavior of the Business Central image doesn't require manually mounting custom scripts. You can just include them in your configuration to let the chart automatically set them up for you.
- **Use external databases**: Instead of using the database included within the artifacts or your custom pre-built image you can easily use an external database.
- **Configuration via environment variables**: While the usage of some options of the Business Central image is simplified through the exposed chart configuration, you can still define environment variables to pass directly to the container for advanced scenarios.
- **Automatically publishing AL extensions on startup (experimental)**: The chart provides options for automatically downloading AL extensions from a NuGet feed and publish them via the development endpoint. This helps to e.g. quickly set up an environment with the newest build from your pipeline.
- **Disabling access to endpoints**: For some environments you may want to disable external access to some endpoints like the ones for development, OData or SOAP. This is easily possible through the configuration.
- ...

I already described all those scenarios [in detail in the documentation](https://artifacthub.io/packages/helm/lippertmarkus/business-central#using-artifacts-and-pre-built-images) of the chart, so I won't repeat them here. Now that you got the basics set up, you can head over to the [Business Central Helm Chart on Artifact HUB](https://artifacthub.io/packages/helm/lippertmarkus/business-central#using-artifacts-and-pre-built-images) and try them out! You can use the configuration described there with the Business Central environment you installed before like:

```powershell
# Upgrade the existing instance
helm upgrade -i bc1 lippertmarkus/business-central -f config.yml --set service.type=LoadBalancer
```

## There's more

If you're curious how the source of the Chart looks like, have a look at the [GitHub repo](https://github.com/lippertmarkus/helm-charts/tree/master/charts/business-central). I'm also open to contributions if anyone of you want to help improve the Helm chart further.

For a detailed reference of all available configuration options of the Helm chart, have a look at the [Configuration reference](https://artifacthub.io/packages/helm/lippertmarkus/business-central#configuration-reference). Next to the ones described in the [common scenarios](https://artifacthub.io/packages/helm/lippertmarkus/business-central#common-scenarios), there are also a lot of Kubernetes-specific ones.
