Follow quickstart: https://cluster-api.sigs.k8s.io/user/quick-start.html


before `clusterctl init` also set:
```
export EXP_AKS=true
export EXP_MACHINE_POOL=true
export EXP_CLUSTER_RESOURCE_SET=true
```

generate cluster with template (TODO REPLACE WITH FLAVOR PARAMETER):
```bash
$ wget https://raw.githubusercontent.com/kubernetes-sigs/cluster-api-provider-azure/main/templates/cluster-template-machinepool-windows-containerd.yaml
$ clusterctl generate cluster mycluster --kubernetes-version v1.22.3 --control-plane-machine-count=1 --worker-machine-count=1 --from cluster-template-machinepool-windows-containerd.yaml > mycluster.yaml
$ kubectl apply -f mycluster.yaml

# check and wait for provisioning to finish
clusterctl describe cluster mycluster
kubectl get kubeadmcontrolplane

# create kubeconfig for new cluster
clusterctl get kubeconfig mycluster > mycluster.kubeconfig
```

install CNI via Cluster Resource Set:
```bash
# CNI linux
wget https://raw.githubusercontent.com/kubernetes-sigs/cluster-api-provider-azure/main/templates/addons/calico.yaml
kubectl create configmap calico-addon --from-file=calico.yaml

# CNI and kube-proxy for Windows
mkdir calico-windows
curl https://raw.githubusercontent.com/kubernetes-sigs/cluster-api-provider-azure/main/templates/addons/windows/calico/calico.yaml -o calico-windows/calico.yaml
curl https://raw.githubusercontent.com/kubernetes-sigs/cluster-api-provider-azure/main/templates/addons/windows/calico/kube-proxy-windows.yaml -o calico-windows/kube-proxy-windows.yaml

# fix envsubst (https://github.com/kubernetes-sigs/cluster-api-provider-azure/pull/1831)
sed 's/${KUBERNETES_VERSION\/+\/_}/${KUBERNETES_VERSION}/' calico-windows/kube-proxy-windows.yaml

export KUBERNETES_VERSION=v1.22.3  # if not set from before
kubectl create configmap calico-windows-addon --from-file=calico-windows --dry-run=client -o yaml | envsubst \$KUBERNETES_VERSION | kubectl apply -f -

# create ClusterResourceSets to apply all previos addons to all "calico" clusters
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/cluster-api-provider-azure/main/templates/addons/calico-resource-set.yaml
```

# TODO WAIT FOR https://github.com/kubernetes-sigs/cluster-api-provider-azure/issues/1832

```
root@Markus-Laptop:/mnt/c/Users/mlippert9438# kubectl --kubeconfig=./mycluster.kubeconfig get node
NAME                            STATUS   ROLES                  AGE     VERSION
mycluster-control-plane-pfm8n   Ready    control-plane,master   8m46s   v1.22.3
mycluster-mp-0000000            Ready    <none>                 7m19s   v1.22.3
win-p-win000000                 Ready    <none>                 6m30s   v1.22.3
```