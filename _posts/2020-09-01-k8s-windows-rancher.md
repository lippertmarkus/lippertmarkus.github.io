---
title: "Easily create Kubernetes Clusters with Windows Support via Rancher"
image: "/img/thumbnails/k8s-win-rancher.png"
bigimg: "/img/ship-wheel2.jpg"
tags: [Kubernetes,Containers,Windows,Docker]
---

Kubernetes [supports Windows](https://kubernetes.io/docs/setup/production-environment/windows/intro-windows-in-kubernetes/) since v1.14 and with the latest releases the support got even better. All managed Kubernetes services of the major cloud providers support Windows containers. Microsoft as one of them [announced](https://azure.microsoft.com/en-us/blog/announcing-the-general-availability-of-windows-server-containers-and-private-clusters-for-azure-kubernetes-service/) the general availability of Windows containers for Azure Kubernetes Service (AKS) in April 2020. 

But what if you don't want to or can't use a managed Kubernetes service but still would like to try out Windows support in Kubernetes? Although Kubernetes provides a [documentation](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/adding-windows-nodes/) on how to add Windows nodes to your existing cluster, the setup is rather complex and contains a lot of manual steps. 

This is where [Rancher](https://rancher.com/) comes into play. Rancher is a container management plattform and allows creating Kubernetes Clusters with Windows support through executing a single command on each node you want to add to your Kubernetes cluster.

## TL;DR

The shortest path is to use the Terraform definitions I created for automatically setting up VMs on Azure or locally (with Vagrant) and creating a new mixed cluster with Linux and Windows nodes via Rancher in a fully automated way. Go [to that section](#automate-everything-with-terraform) of the post to read more.

In case you don't want to use the Terraform definitions and create the cluster by yourself with the help of Rancher or just want to know more details, read on! That path is a bit more manual but still very easy and quick compared to the steps described in the Kubernetes docs.

## Details

In the following I give you short background around Kubernetes, Rancher, Terraform and Vagrant. I explain in more detail what VMs you need and how you would set them up as well as create a new cluster via Rancher and add Nodes to that cluster.

### Background

[Kubernetes](https://kubernetes.io) is a container orchestration system which makes deploying and managing containerized applications easy. A Kubernetes cluster consists of multiple nodes, mostly VMs or physical machines. Each of those nodes has one or many roles, for example to schedule the container workloads (Control Plane), storing the cluster data (etcd) or running workloads (Worker).

[Rancher](https://rancher.com/) helps with provisioning, managing and monitoring multiple Kubernetes clusters as well as deploying workloads onto them. It also provides security and user management.

[Terraform](https://www.terraform.io/) allows you to define infrastructure as code to fully automate the management of infrastructure with different cloud providers as well as services. Terraform has a [registry](https://registry.terraform.io/) with dozens of official and community providers and modules to simplify the interaction with the cloud provider and service APIs. I used Terraform to automatically set up the infrastructure either on [Azure](https://azure.microsoft.com/en-us/) locally via Vagrant. [Vagrant](https://www.vagrantup.com/) automates the creation and provisioning of local VMs with different hypervisors like Hyper-V, Virtualbox and others. Vagrant provides a [registry for Boxes](https://app.vagrantup.com/boxes/search) which are basically VM images.

### Architecture

A simple test environment for running Windows containers in Kubernetes via Rancher consists of:
- Rancher Server to set up and manage your Kubernetes cluster
    - Single [Linux VM with Docker](https://rancher.com/docs/rancher/v2.x/en/installation/other-installation-methods/single-node-docker/) to run Rancher itself.
   
- Mixed Kubernetes Cluster with Windows and Linux nodes for running Windows containers
    - One Linux node with Docker to use as Control Plane, etcd and Worker for Linux workloads 
    - One or more Windows nodes with Docker to use as worker for Windows workloads

Like mentioned you can use the [Terraform definitions](#automate-everything-with-terraform) to set up those VMs on Azure or locally or create them by yourself. For the Linux nodes you can use any distribution like Ubuntu and just need to install Docker like described [here](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository) or choose a lightweight distribution with Docker preinstalled. For the Windows node(s) choose Windows Server 2019 and make sure that [Docker EE is installed](https://hub.docker.com/editions/enterprise/docker-ee-server-windows). Each VM should have at least 2 vCPUs and either 4 GB (Linux) or 8 GB (Windows) of RAM.

### Setting up Rancher

Log-in to the single Linux node where you want to run Rancher and start the Docker container:
```bash
docker run -d --restart=unless-stopped -p 80:80 -p 443:443 rancher/rancher:latest
```

After a few seconds you can access the Rancher Dashboard at `https://rancher-node/`, set up a password and start creating your mixed cluster.

### Creating your mixed cluster

You can now easily create a new mixed cluster via the Rancher UI and join the Kubernetes nodes with a single command:

<div class="center" markdown="1">
  <img class="lazy" alt="Create a Windows cluster and add nodes via Ranche UI" data-src="/assets/posts/k8s-windows-rancher/create-cluster.gif" />
</div>

**Steps**:
1. In *Global* view under the *Cluster* tab create a new cluster and choose *From existing nodes*
2. Enter a name, choose *Flannel* as network provider, enable *Windows Support* and click *Next*
3. Under *Node Operating System* check *Linux*, enable all three roles and run the displayed command on your Linux node
4. Now choose *Windows* under *Node Operating System* and run the command on your Windows worker node.
5. Click *Done* and wait around 10 minutes until your cluster is healthy:

<div class="center" markdown="1">
  <img class="lazy" alt="Ready cluster in Rancher UI" data-src="/assets/posts/k8s-windows-rancher/rancher-cluster.jpg" />
</div>

It's as simple as that! Now you can [deploy a Windows workload](#deploy-a-windows-workload) and access it via ingress.

Still too much work? Let's see how we can take this one step further and use Terraform to automatically create the infrastructure and handle that five steps I just described for us.

## Automate everything with Terraform

To automatically set up VMs, Rancher, the mixed cluster and join the nodes I used [Terraform](https://www.terraform.io/). Terraform allows to define infrastructure as code and automatically provision it. It supports different cloud providers [like Azure](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs). There's also a [Rancher provider](https://registry.terraform.io/providers/rancher/rancher2/latest/docs) I used to automatically bootstrap the Rancher installation and the cluster setup.

You can find the [repository on GitHub](https://github.com/lippertmarkus/terraform-k8s-windows-rancher). Per default it uses Azure for provisioning the VMs so you need to [install the Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?view=azure-cli-latest&tabs=azure-cli) first. Also make sure to [install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) itself. Afterwards you can provision the infrastructure as following:
```bash
git clone https://github.com/lippertmarkus/terraform-k8s-windows-rancher.git
cd terraform-k8s-windows-rancher
az login  # log in to your Azure account
terraform init  # initialize terraform
terraform apply -auto-approve  # provision infrastructure
```

You can also use the available parameters to create local VMs with Hyper-V and Vagrant instead of using Azure. You need to [install Vagrant](https://www.vagrantup.com/downloads) as well as [Hyper-V](https://docs.microsoft.com/de-de/virtualization/hyper-v-on-windows/quick-start/enable-hyper-v) for this to work. Afterwards you can use the following command instead:
```bash
# Alternative to the command above: create local VMs with Vagrant instead of using Azure
terraform apply -auto-approve -var 'vagrant_enable=true' -var 'vagrant_vswitch=myswitch'  # provision infrastructure
```

The parameter `vagrant_vswitch` must be set to the name of a virtual switch with external connectivity. It can be found via the *Manager for virtual switches* inside the *Hyper-V Manager*.

When using Vagrant the initial download of the VM Images (*Boxes*) takes a bit depending on your network. Afterwards, regardless of whether you use Azure or Hyper-V, the setup of the mixed cluster takes around 10 minutes. After completion of the `terraforma apply` command you get the URL to access the Rancher UI as well as the admin credentials:
```bash
# ...
Apply complete! Resources: 27 added, 0 changed, 0 destroyed.

Outputs:

rancher_admin_password = lrN6%R}gx<FgtiOy
rancher_admin_user = admin
rancher_url = https://40.68.17.99
```

Via the Rancher UI you can track the provisioning of the Kubernetes nodes themselves which should take another 10 minutes. The resulting cluster is the same as the one created manually.

## Deploy a Windows workload

Here's an example on how to use Rancher to deploy a simple Windows application to your Kubernetes cluster and set up an ingress rule to access it:

<div class="center" markdown="1">
  <img class="lazy" alt="Deploy a Windows application and set up ingress rule via Rancher UI" data-src="/assets/posts/k8s-windows-rancher/deployment.gif" />
</div>

## There's more

Rancher greatly simplifies the setup of a mixed Kubernetes cluster so you can get started quickly. Keep in mind that this is just a test environment. It's great for getting a deeper knowledge of all the components. 

For a production environment most people tend to use a hosted Kubernetes service like AKS which you could also [manage via Rancher](https://rancher.com/docs/rancher/v2.x/en/cluster-provisioning/hosted-kubernetes-clusters/aks/). If you instead want to build your own, you should run Rancher in a seperate Kubernetes cluster with a load balancer to enable high-availability like explained in [the docs](https://rancher.com/docs/rancher/v2.x/en/installation/how-ha-works/). You can also find [recommendations](https://rancher.com/docs/rancher/v2.x/en/installation/k8s-install/create-nodes-lb/) and [a checklist](https://rancher.com/docs/rancher/v2.x/en/cluster-provisioning/production/) about production Kubernetes clusters managed by Rancher there.