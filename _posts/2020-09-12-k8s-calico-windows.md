---
title: "Networking with Calico for Windows in mixed Kubernetes clusters"
image: "/img/thumbnails/k8s-calico-windows.png"
bigimg: "/img/network.jpg"
tags: [Kubernetes,Containers,Windows,Azure]
---

Project Calico [recently](https://www.projectcalico.org/whats-new-in-calico-3-16/) made Calico for Windows open-source. Before it was only available [through a subscription](https://www.tigera.io/tigera-products/calico-for-windows/). This means there is now another open-source networking plugin next to Flannel (and cloud-specific ones like Azure-CNI) which you can use for your mixed Kubernetes cluster with both Linux and Windows nodes. Calico for Windows only supports VXLAN for now and like Flannel also uses overlay networking. In addition Calico also allows to create network policies to control the traffic in your cluster.

To quickly try it out I created Terraform definitons to automatically spin up a Kubernetes cluster on Azure for testing. If you want to set it up yourself, you can have a look at the provisioning scripts described later. After setting up the infrastructure we'll have a look at how the network policies work.

## TL;DR

You need to install the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?view=azure-cli-latest&tabs=azure-cli) as well as [Terraform](https://www.terraform.io/downloads.html). To setup the mixed cluster with Calico for Windows as a networking plugin run the following commands:

```bash
# Create a mixed Kubernetes cluster with Calico for Windows
git clone https://github.com/lippertmarkus/terraform-azurerm-k8s-calico-windows.git
cd terraform-azurerm-k8s-calico-windows
az login   # log in to your Azure account
terraform init  # initialize terraform
terraform apply -auto-approve  # provision infrastructure

# Check the cluster and deploy an example Windows workload
ssh -i output/primary_pk azadmin@$(terraform output primary_ip)
kubectl get node
kubectl get pod -A
kubectl apply -f https://raw.githubusercontent.com/lippertmarkus/terraform-azurerm-k8s-calico-windows/master/example_workloads/win-webserver.yml
```

If you don't want to know the details around the Calico for Windows installation, try [setting up network policies](#creating-network-policies).

## Details

[Kubernetes](https://kubernetes.io) is a container orchestration system which makes deploying and managing containerized applications easy. A Kubernetes cluster consists of multiple nodes, mostly VMs or physical machines. Each of those nodes has one or many roles, for example to schedule the container workloads (Control Plane), storing the cluster data (etcd) or running workloads (Worker). Kubernetes [supports](https://kubernetes.io/docs/setup/production-environment/windows/intro-windows-in-kubernetes/) both Linux and Windows worker nodes in mixed clusters.

Networking for Windows containers is done through Container Networking Interface (CNI) Plugins like Flannel or Calico for Windows which in a heterogeneous cluster must support both Windows and Linux nodes. Find out more about networking for Windows containers in the [Kubernetes docs](https://kubernetes.io/docs/setup/production-environment/windows/intro-windows-in-kubernetes/#networking).


### Creating a mixed cluster with Calico for Windows

The Terraform definitions spin up two VMs on Azure with a shared virtual network and public IPs to form a Kubernetes cluster: 
- Linux VM `primary` using Ubuntu as a control plane, for etcd and for running Linux workloads
- Windows VM `minion` using Windows Server 1903 with Docker preinstalled for running Windows workloads

To use the definitions you need to install the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?view=azure-cli-latest&tabs=azure-cli) as well as [Terraform](https://www.terraform.io/downloads.html) and run the following commands to clone the Git repository, log in to your Azure account and provision the infrastructure:
```bash
# Create a mixed Kubernetes cluster with Calico for Windows
git clone https://github.com/lippertmarkus/terraform-azurerm-k8s-calico-windows.git
cd terraform-azurerm-k8s-calico-windows
az login   # log in to your Azure account
terraform init  # initialize terraform
terraform apply -auto-approve  # provision infrastructure
```

The more or less interesting part happens inside the provisioning scripts. The [script for the `primary` node](https://github.com/lippertmarkus/terraform-azurerm-k8s-calico-windows/blob/master/scripts/cloud-config.yml#L6-L59) initializes a new Kubernetes cluster with `kubeadm` through the steps outlined in the [`kubeadm` docs](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/). Before the cluster is initialized the networking gets set up and the needed prerequisites `docker`, `kubelet`, `kubeadm` and `kubectl` are installed.

Afterwards Calico with etcd as a datastore is installed on the Linux node via the manifest like described in the [Calico docs](https://docs.projectcalico.org/getting-started/kubernetes/self-managed-onprem/onpremises#install-calico-with-etcd-datastore). I [adapted the Calico manifest](https://github.com/lippertmarkus/terraform-azurerm-k8s-calico-windows/blob/master/scripts/cloud-config.yml#L63-L634) to use VXLAN and TLS for etcd. VXLAN is required for Calico for Windows and you also need to enable strict affinity for Calico to prevent Linux nodes from borrowing IP addresses from Windows nodes like [stated in the docs](https://docs.projectcalico.org/getting-started/windows-calico/standard#install-calico-on-linux-control-and-worker-nodes) and done by the provisioning script. The script also adds the secret values for the etcd TLS connection as well as the etcd endpoint itself to the manifest before installing it.

As the cluster is now created, the Windows node is automatically joined to the cluster. The [PowerShell script](https://github.com/lippertmarkus/terraform-azurerm-k8s-calico-windows/blob/master/scripts/win-cluster-join.ps1) which is run on the `minion` Windows node first copies the kubeconfig as well as the etcd TLS certificates from the `primary` node. The kubeconfig is needed by Calico for accessing the API server to correctly set up networking for each pod and the TLS certificates are used for securely connect to the etcd datastore. Lastly the installation script provided by Calico fully sets up Calico for Windows as well as the Kubernetes services and starts them. For creating the PowerShell provisioning script I followed the docs about the [standard install](https://docs.projectcalico.org/getting-started/windows-calico/standard) as well as the [quickstart](https://docs.projectcalico.org/getting-started/windows-calico/quickstart) and combined the information. The script mainly follows the documentation of the quickstart but this path unfortunately lacks options to automatically [set up the calico-kubeconfig](https://docs.projectcalico.org/getting-started/windows-calico/kubeconfig) as well as TLS for etcd for self managed clusters although there are already functions for that. I therefore modified the installation script.

### Accessing the cluster

After `terraform apply` is finished, you can connect to the `primary` node to access and manage the cluster as well as verify that everything works as expected:

```bash
ssh -i output/primary_pk azadmin@$(terraform output primary_ip)
kubectl get node
kubectl get pod -A
```

Now you can deploy a simple Windows workload to make sure Calico on Windows was installed properly:
```bash
kubectl apply -f https://raw.githubusercontent.com/lippertmarkus/terraform-azurerm-k8s-calico-windows/master/example_workloads/win-webserver.yml
```

The following network connections should work:
- Node-to-Pod from the `primary` Linux node using the Pod IP
- Pod-to-Pod on the same node and across nodes
- Pod-to-Service from within a Pod and Service-to-Pod from the `primary` Linux node using the cluster IP of the service
- Service Discovery via DNS from within a Pod
- Inbound-to-Pod from the `primary` Linux node using the `minion` IP and the services' NodePort 

Like for Flannel you can't access the Pod IP, the services' cluster IP or the NodePort on the Windows container host. Let's have a look at the Pod-to-Pod connections and how we can control them by applying network policies.

## Creating network policies

The Calico docs have a [simple guide](https://docs.projectcalico.org/getting-started/windows-calico/demo) illustrating the use of network policies. I adapted the examples a bit to work for Windows Server 1903 and to make them a bit more easy to understand. Let's see how they are used by following the steps:

1. Deploy a client and server Pod on each the Linux and Windows node
    ```bash
    kubectl apply -f https://raw.githubusercontent.com/lippertmarkus/terraform-azurerm-k8s-calico-windows/master/example_workloads/policy-demo-pods.yml
    ```
2. Verify the connection from `linux-client` to `windows-server`:
    ```bash
    kubectl exec -n calico-demo linux-client -- nc -vz $(kubectl get po windows-server -n calico-demo -o 'jsonpath={.status.podIP}') 80
    # This should succeed with output similar to
    # 192.168.115.74 (192.168.115.74:80) open
    ```
3. Verify the connection from `windows-client` to `linux-server`:
    ```bash
    kubectl exec -n calico-demo windows-client -- powershell Invoke-WebRequest -Uri http://$(kubectl get po linux-server -n calico-demo -o 'jsonpath={.status.podIP}') -UseBasicParsing -TimeoutSec 5
    # This should succeed with output similar to
    # ...
    # <title>Welcome to nginx!</title>
    # ...
    ```
4. Verify the connection from `windows-client` to `windows-server`:
    ```bash
    kubectl exec -n calico-demo windows-client -- powershell Invoke-WebRequest -Uri http://$(kubectl get po windows-server -n calico-demo -o 'jsonpath={.status.podIP}') -UseBasicParsing -TimeoutSec 5
    # This should succeed with output similar to
    # ...
    # <html><body><H1>Windows Container Web Server</H1><p>IP
    # ...
    ```
5. Apply the network policy to only allow connections from `linux-client` to `windows-server`:
    ```bash
    wget https://raw.githubusercontent.com/lippertmarkus/terraform-azurerm-k8s-calico-windows/master/example_workloads/policy-demo-policy.yml
    calicoctl apply -f policy-demo-policy.yml
    ```
6. Verify that the `linux-client` is still able to reach `windows-server`:
    ```bash
    kubectl exec -n calico-demo linux-client -- nc -vz $(kubectl get po windows-server -n calico-demo -o 'jsonpath={.status.podIP}') 80
    ```
7. Verify that other connections like e.g. from `windows-client` to `windows-server` are not working:
    ```bash
    kubectl exec -n calico-demo windows-client -- powershell Invoke-WebRequest -Uri http://$(kubectl get po windows-server -n calico-demo -o 'jsonpath={.status.podIP}') -UseBasicParsing -TimeoutSec 5
    # This should time out like
    # Invoke-WebRequest : The operation has timed out.
    # ...
    ```

That's how you can isolate Pod-to-Pod traffic. You can remove the demo resources with `kubectl delete ns calico-demo`.

## Conclusion

It's great to have another option next to Flannel for networking within mixed clusters. While the basic networking works fine, keep in mind that there are still [limitations](https://docs.projectcalico.org/getting-started/windows-calico/limitations) for Calico for Windows. 
