---
title: "Kubernetes-native CI/CD with Windows container support of Tekton"
image: "/img/thumbnails/k8s-tekton-win.png"
bigimg: "/img/cloud.jpg"
tags: [Kubernetes,Containers,Windows,Azure,DevOps]
---

Kubernetes-native CI/CD systems build upon containers and Kubernetes as a runtime environment and use Kubernetes resources like Jobs for running the steps of your pipeline. This enables reproducability, performance, autoscaling & highly parallel jobs for your pipelines. 

The number of Kubernetes-native CI/CD systems in the [CNCF](https://landscape.cncf.io/category=continuous-integration-delivery&format=card-mode&grouping=category) and the [CDF](https://landscape.cd.foundation/card-mode?category=ci-pipeline-orchestration&grouping=category) Landscape is limited. When looking for Windows container support, only [Argo Workflows](https://argoproj.github.io/projects/argo) and [Tekton](https://tekton.dev/) are viable options.

I already looked at Windows container support of Argo Workflows in [a previous post]({% post_url 2020-10-15-cloud-native-ci-cd-windows-argo.md %}). It has further improved since then but recently also Tekton added support for Windows Containers providing us with a second option to choose from. Tekton is a cloud-native solution for building CI/CD pipelines with a focus on flexibility, reusability, extensibility & scalability.

## TL;DR

You need to have a hybrid Kubernetes cluster with a Linux node for running Tekton and at least one Windows node to run Windows containers in your pipelines. To achieve that you could e.g. create an [AKS cluster with a Windows Server node pool](https://docs.microsoft.com/en-us/azure/aks/windows-container-cli).

With [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) you can now install Tekton and optionally the Tekton Dashboard:

```bash
# Install Tekton Pipelines
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.33.1/release.yaml

# Optional: Install Tekton dashboard
kubectl apply -f https://storage.googleapis.com/tekton-releases/dashboard/latest/tekton-dashboard-release.yaml
# Make dashboard available via LoadBalancer service
kubectl patch svc tekton-dashboard -n tekton-pipelines -p '{\"spec\": {\"type\": \"LoadBalancer\"}}'
# Get external IP of the dashboard (may wait a few seconds)
kubectl get svc tekton-dashboard -n tekton-pipelines --template "{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}"

# Run your first pipeline
kubectl apply -f https://raw.githubusercontent.com/lippertmarkus/presentations/main/2021-02-FOSDEM-CICD/hello-world-pipelines/tekton.yml
```

Now open `http://<external-ip>:9097` in your browser and follow the pipeline you just started:

<div class="center" markdown="1">
  <img class="lazy" alt="Overview of a successful pipeline in the Tekton dashboard" data-src="/assets/posts/k8s-native-ci-cd-windows-tekton/finished-pipeline.png" />
</div>

## Details

### Windows container support in Tekton

Tekton added basic Windows Container support in [October 2021](https://github.com/tektoncd/pipeline/issues/1826). Tekton components continue to run on Linux nodes but Tekton allows you to run Windows specific steps in your pipelines via Windows containers. You can control where your tasks are executed by using [Node Selectors or Node Affinity specifications](https://tekton.dev/docs/pipelines/windows/#scheduling-tasks-on-windows-nodes).

Tekton allows to use Workspaces to share files between tasks in your pipelines. There were some [changes needed](https://github.com/tektoncd/pipeline/issues/4473) to make these work flawlessly with Windows containers. All other features of Tekton I tried so far did also work well with Windows containers. If you find issues, feel free to [report them and provide feedback](https://github.com/tektoncd/pipeline) to the maintainers.


### Installing Tekton in your mixed Kubernetes cluster

You can use any cluster with at least one Windows node for the Windows tasks in your pipelines. Almost any cloud provider with a managed Kubernetes offering allows to add a Windows node pool. For AKS you can find the docs [here](https://docs.microsoft.com/en-us/azure/aks/windows-container-cli).

The easiest way to install Tekton in your cluster is to use the [official manifests](https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.32.0/release.yaml):

```bash
# Install Tekton Pipelines
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.33.1/release.yaml
```

Optionally you can also install the Tekton dashboard to get a more visual view on the pipelines we're about to run:
```bash
# Install Tekton dashboard
kubectl apply -f https://storage.googleapis.com/tekton-releases/dashboard/latest/tekton-dashboard-release.yaml

# Make dashboard available via LoadBalancer service
kubectl patch svc tekton-dashboard -n tekton-pipelines -p '{\"spec\": {\"type\": \"LoadBalancer\"}}'

# Get external IP of the dashboard (may wait a few seconds)
kubectl get svc tekton-dashboard -n tekton-pipelines --template "{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}"
```

I used a `LoadBalancer` service for external access to the Tekton dashboard. After a couple of seconds you should be able to access the dashboard via `http://<external-ip>:9097` and are ready to schedule your first hybrid pipeline.

## Schedule hybrid pipelines

With Tekton installed you can now run Linux-only, Windows-only and hybrid workflows. A very simple example for a hybrid *Hello World* pipeline could look like the following:

```yaml
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: hello-world
spec:
  pipelineSpec:
    tasks:
      - name: task-win
        taskSpec:
          steps:
            - name: hello-windows
              image: mcr.microsoft.com/windows/nanoserver:1809
              command: ["cmd", "/c"]
              args: ["echo", "Hello from Windows Container!"]
      - name: task-lin
        taskSpec:
          steps:
            - name: hello-linux
              image: alpine
              command: ["echo"]
              args: ["Hello from Linux Container!"]    
  taskRunSpecs:
    - pipelineTaskName: task-win
      taskPodTemplate:
        nodeSelector:
          kubernetes.io/os: windows  # runs on Windows
        securityContext:
          windowsOptions:
            runAsUserName: "ContainerAdministrator"
    - pipelineTaskName: task-lin
      taskPodTemplate:
        nodeSelector:
          kubernetes.io/os: linux  # runs on Linux
```

A Tekton pipeline consists of a collection of tasks. Each task represents one Kubernetes pod at runtime where each step in that task is a container in this pod. This also means that tasks run in parallel when not specified otherwise (e.g. with `runAfter`) and that you can't mix Linux and Windows containers within the same task.

Pipelines and Tasks are just the specification of the steps to be executed. When running a pipeline those specifications get instantiated as `PipelineRun`s and `TaskRun`s. This is also where you would specify runtime specific options like the Node Selectors as in the example above. Refer to the [Tekton documentation](https://tekton.dev/docs/concepts/) for more details on the general concepts of Tekton.

With those basic concepts in mind the pipeline example above should be self-explaining. After submitting it with `kubectl apply -f pipeline.yml` you can follow the progress and the logs within the dashboard:

<div class="center" markdown="1">
  <img class="lazy" alt="Overview of a successful pipeline in the Tekton dashboard" data-src="/assets/posts/k8s-native-ci-cd-windows-tekton/finished-pipeline.png" />
</div>

## There's more

Go ahead and learn more about [Tekton](https://tekton.dev/docs/overview/) and its [Windows support](https://tekton.dev/docs/pipelines/windows/) and compare it to [Argo Workflows](https://argoproj.github.io/projects/argo) to see which Kubernetes-native CI/CD system fits you better.

You can also have a look at a [more sophisticated example](https://github.com/lippertmarkus/presentations/blob/main/2021-02-FOSDEM-CICD/pipelines/out/tekton-crane.yml) on hybrid pipelines using Tekton to build source code in a Windows container and use a Linux container to create a Windows container image based on the created binary.