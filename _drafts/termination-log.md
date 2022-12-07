---
title: "Return values from Kubernetes Jobs easily "
image: "TODO"
bigimg: "TODO"
tags: [TODO]
---

- we have an API that schedules k8s jobs to do some work
- a simple "success" or "failure" is not enough as a result from the job, we need to return values
- two options
    a) post the results from job to the API either directly (sync) or via a message broker (async but additional complexity)
    b) common data store, e.g. shared files, db, write config map etc.

instead of fiddling around with shared volumes or other external storage that is very disconnected from your job you can just use the Job object itself. 

So without even granting the Job access to the K8s api you can just use terminationMessage