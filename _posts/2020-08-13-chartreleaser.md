---
title: "Host Helm Charts via GitHub with Chart Releaser"
image: /img/thumbnails/helm.jpg
bigimg: "/img/ship-wheel.jpg"
tags: [Kubernetes,Helm,GitHub,Containers,Docker]
---

As Helm just released the first stable version of [Chart Releaser](https://github.com/helm/chart-releaser), it's worth to take a look at how it helps you to easily host Helm Charts using GitHub Releases, GitHub Pages and GitHub Actions.

## TL;DR

Go directly to the [setup of the Chart Releaser GitHub Action](#setting-up-the-chart-releaser-github-action).

## Background

[Kubernetes](https://kubernetes.io) is a container orchestration system which makes deploying and managing containerized applications easy. Kubernetes itself uses multiple YAML files to define all resources an application needs. Managing multiple such files is rather cumbersome and the configurations are static, they aren't easily portable. This is where Helm comes in.

[Helm](https://helm.sh) is currently the de-facto package manager for Kubernetes and makes the installation and management of applications easy. It bundles Kubernetes resources within a Helm Chart. It also allows to parameterize the YAML files, making the applications reusable and simplifying the installation.

Helm Charts can be installed from the local filesystem or via a Chart Repository - just like Docker images. According to the [Helm docs](https://helm.sh/docs/topics/chart_repository/) a chart repository is just a HTTP server with an `index.yaml` file. This index contains all available charts with the name, description, versions and a link to a tar file which contains the compressed Chart.

[Chart Releaser](https://github.com/helm/chart-releaser) benefits from this simple repository architecture. It allows you to automatically create [GitHub releases](https://help.github.com/en/github/administering-a-repository/about-releases) and attach the Chart tar file to them:

<div class="center" markdown="1">
  <img class="lazy" alt="Chart Release automatically created by Chart Releaser" data-src="/assets/posts/chartreleaser/release.png" />
</div>

For publishing the index it uses [GitHub Pages](https://pages.github.com/) which can serve static files within a `gh-pages` branch under `https://<owner>.github.io/<project>`.

To automatically run Chart Releaser to create a release and update the index, you can use [GitHub Actions](https://github.com/features/actions). GitHub Actions allows running a workflow whenever a new change in a Git repository happens or when a Pull Request is created. The Helm team provides you with a ready-to-use [GitHub Action for Chart Releaser](https://github.com/helm/chart-releaser-action/) so you don't need to create scripts to run the CLI tool yourself. Let's see how to use this action.

## Setting up the Chart Releaser GitHub Action

Just follow the following steps outlined in the [Chart Releaser Action repo](https://github.com/helm/chart-releaser-action):

1. Create a GitHub repo with your Charts stored in a directory `/charts`.
1. Make a `gh-pages` branch. Your chart index will be stored there.
1. Add a new GitHub Actions workflow in `.github/workflows/release.yml` with the following content:\\
    \\
    ```yaml
    name: Release Charts
    on:
      push:
        branches:
          - master
    jobs:
      release:
        runs-on: ubuntu-latest
        steps:
          - name: Checkout
            uses: actions/checkout@v1

          - name: Configure Git
            run: |
              git config user.name "$GITHUB_ACTOR"
              git config user.email "$GITHUB_ACTOR@users.noreply.github.com"

          - name: Run chart-releaser
            uses: helm/chart-releaser-action@v1.0.0
            env:
              CR_TOKEN: "{{ "${{ secrets.GITHUB_TOKEN " }}}}"
    ```
    You don't need to add any secrets. All the variables used within the workflow are available automatically.

When you now push a change to your `master` branch, the action checks each chart for a new version. For updated charts it creates a GitHub Release and adds the chart artifact `*.tgz` file to the release. Now the `index.yaml` file on the `gh-pages` branch is updated to add your new chart version with the link to the GitHub Releases artifact. 

You can then use the GitHub page of the project as a chart repo:
```bash
helm repo add myrepo https://<owner>.github.io/<project>
helm install myapp myrepo/myapp
```

I created [an example repository](https://github.com/lippertmarkus/helm-charts) for you to have a look at. For more details, check out the Repo of the [Chart Releaser GitHub action](https://github.com/helm/chart-releaser-action/) as well as the [Chart Releaser CLI tool](https://github.com/helm/chart-releaser) itself.

## Use a custom domain

If you have a custom domain, you can use that for your chart repository. Like for all GitHub Pages you can configure it via your Project Settings:

<div class="center" markdown="1">
  <img class="lazy" alt="Setting up a custom domain" data-src="/assets/posts/chartreleaser/custom-domain.png" />
</div>


## There's more

You can also add GitHub workflows to lint and test your charts with the [Chart Testing Action](https://github.com/helm/chart-testing-action). It can be used together with the [Kind Action](https://github.com/helm/kind-action) to set up Kubernetes in Docker (kind) to verify the installation of your charts.