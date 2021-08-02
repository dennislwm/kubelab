# kubectllab

`kubectl` starter project on **Ubuntu 16.04**.

<!-- TOC -->

- [kubectllab](#kubectllab)
  - [TL;DR](#tldr)
  - [Project](#project)
    - [Requirements](#requirements)
    - [Installing Kubernetes and Docker on all three servers](#installing-kubernetes-and-docker-on-all-three-servers)
    - [Kubernetes API Primitives](#kubernetes-api-primitives)
    - [Creating Pods](#creating-pods)
    - [Namespaces](#namespaces)
    - [Basic Container Configuration](#basic-container-configuration)
    - [ConfigMaps](#configmaps)
    - [SecurityContexts](#securitycontexts)
    - [Resource Requirements](#resource-requirements)
    - [Secrets](#secrets)
    - [ServiceAccounts](#serviceaccounts)
    - [Understanding Multi-Container Pods](#understanding-multi-container-pods)
    - [Design Patterns for Multi-Container Pods](#design-patterns-for-multi-container-pods)
    - [Liveness and Readiness Probes](#liveness-and-readiness-probes)
    - [Container Logging](#container-logging)
    - [Installing Metrics Server](#installing-metrics-server)
    - [Monitoring Applications](#monitoring-applications)
    - [Debugging](#debugging)
    - [Labels, Selectors, and Annotations](#labels-selectors-and-annotations)
    - [References](#references)

<!-- /TOC -->

## TL;DR

`kubectl` is **Kubernetes**, focusing on making it easy to learn and develop for **Kubernetes**.

## Project

### Requirements

Three virtual machines, for each one you'll need:
* 2 virtual CPUs or more
* 4Gb of free memory
* 20Gb of free disk space
* Internet connection
* Container or virtual machine manager

### Installing Kubernetes and Docker on all three servers

First setup the Kubernetes and Docker repositories.

```sh
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) \
stable"
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat << EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
```

Install Kubernetes and Docker packages.

_Note: If you want to use a newer version of Kubernetes, change the version installed for kubelet, kubeadm, and kubectl. Make sure all three use the same version._

```sh
sudo apt-get update
sudo apt-get install -y docker-ce=18.06.1~ce~3-0~ubuntu kubelet=1.14.5-00 kubeadm=1.14.5-00
kubectl=1.14.5-00
sudo apt-mark hold docker-ce kubelet kubeadm kubectl
```

Enable iptables bridge call.

```sh
echo "net.bridge.bridge-nf-call-iptables=1" | sudo tee -a /etc/sysctl.conf
sudo modprobe br_netfilter
sudo sysctl -p
```

### Kubernetes API Primitives

**Kubernetes API Primitives** are also called *Kubernetes Objects*. These are data objects that represent the state of the cluster.

Examples of Kubernetes Objects:
* Pod
* Node
* Service
* ServiceAccount

The `kubectl api-resources` command will list the object types currently available to the cluster.

Every object has a spec and status.
* **Spec** - You provide this spec. This defines the desired state of the object.
* **Status** - This is provided by the Kubernetes cluster and contains information about the current state of the object.

Kubernetes objects are often represented in the **YAML** format, so you can create an object by providing the cluster with YAML, defining the object and it's spec.

You can get information about an object's spec and status using the `kubectl describe` command.

### Creating Pods

**Pods** are the basic building blocks of any application running in Kubernetes.

A **Pod** consists of one or more containers, and a set of resources shared by those containers. All containers managed by a Kubernetes cluster are part of a pod.

A basic pod in **YAML** format:

```yml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
  labels:
    app: myapp
spec:
  containers:
  - name: myapp-container
    image: busybox
    command: ['sh', '-c', 'echo Hello Kubernetes! && sleep 3600']
```

* **apiVersion** - Kubernetes API version
* **kind** - a Kubernetes object type
* **metadata** - meta about the Kubernetes object
* **labels** - loosely-coupled tags for Kubernetes objects

### Namespaces

**Namespaces** provide a way to keep your objects organized within the cluster. Every object belongs to a namespace.

When no namespace is specified, the cluster will assumee the `default` namespace.

When creating an object, you can assign it to a namespace by specifying a `namespace` in the `metadata`, after `name`.

As an analogy, a Kubernetes **namespace** is similar to a Git **branch**. For example, you can only see pods within the `default` namespace, unless you specify `-n <namespace>`.

### Basic Container Configuration

You can specify the **command** that will be used to run a container in the Pod spec. This will override any built-in default command specified by the container image.

In addition to the **command**, you can also provide custom **arguments**. You can specify `args` in the `container`, after `command`.

_Ports_ are another important part of container configuration. If you need a port that the container is listening on to be exposed to the cluster, you can specify a `containerPort`.

```yml
apiVersion: v1
kind: Pod
metadata:
  name: my-containerport-pod
  namespace: my-namespace
  labels:
    app: myapp
spec:
  containers:
  - name: myapp-container
    image: nginx
    ports:
      containerPort: 80
```

This will allow other clusters to talk to this cluster on port 80.

### ConfigMaps

A **ConfigMap** is a Kubernetes Object that stores configuration data in a key-value format. This configuration data can then be used to configure software running in a container, by referencing the ConfigMap in the Pod spec.

You can create a ConfigMap using `kubectl create` and **YAML** like this:

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config-map
data:
  myKey: myValue
  anotherKey: anotherValue
```

Passing ConfigMap data to a container as an environment variable looks like this:

```yml
apiVersion: v1
kind: Pod
metadata:
  name: my-configmap-pod
spec:
  containers:
  - name: myapp-container
    image: busybox
    command: ['sh', '-c', "echo $(MY_VAR) && sleep 3600"]
    env:
    - name: MY_VAR
      valueFrom:
        configMapKeyRef:
          name: my-config-map
          key: myKey
```

It's also possible to pass ConfigMap data to containers, in the form of file using a mounted volume, like so:

Each top level key from our `my-config-map` is going to become a file in the folder specified by `mountPath`. Each file will contain the value of the key.

```yml
apiVersion: v1
kind: Pod
metadata:
  name: my-configmap-volume-pod
spec:
  containers:
  - name: myapp-container
    image: busybox
    command: ['sh', '-c', "echo $(cat /etc/config/myKey) && sleep 3600"]
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
  volumes:
  - name: config-volume
    configMap:
      name: my-config-map
```

We'll also use the following commands to explore how the ConfigMap data interacts with pods and containers:

```sh
kubectl logs my-configmap-pod
kubectl logs my-configmap-volume-pod
kubectl exec my-configmap-volume-pod -- ls /etc/config
kubectl exec my-configmap-volume-pod -- cat /etc/config/myKey
```

### SecurityContexts

A Pod's **SecurityContext** defines privilege and access control settings for a pod. If a container needs special operating system-level permissions, we can provide them using the SecurityContext.

The SecurityContext is defined as part of a Pod's spec.

```yml
apiVersion: v1
kind: Pod
metadata:
  name: my-securitycontext-pod
spec:
  securityContext:
    runAsUser: 2000
    fsGroup: 3000
  containers:
  - name: myapp-container
    image: busybox
    command: ['sh', '-c', 'cat /message/message.txt && sleep 3600']
```

### Resource Requirements

Kubernetes allows us to specify the resource requirements of a container in the pod spec. A container's memory and CPU requirements are defined in terms of *resource requests* and *limits*.
* Resource request: The amount of resources necessary to run a container. A pod will only run on a node that has enough available resources to run the pod's containers.
* Resource limit: A maximum value for the resource usage of a container.

```yml
apiVersion: v1
kind: Pod
metadata:
  name: my-resource-pod
spec:
  containers:
  - name: myapp-container
    image: busybox
    command: ['sh', '-c', 'echo Hello Kubernetes! && sleep 3600']
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
```

Memory is measured in bytes, e.g. 64Mi means 64 Mebibytes. CPU is measured in cores, e.g. 250m means 250 milliCPUs, or 0.25 CPU cores.

### Secrets

Secrets are pieces of sensitive information stored in the Kubernetes cluster, such as passwords, tokens, and keys.

If a container needs a sensitive piece of information, such as a password, it is more secure to store it as a secret than storing it in a pod spec or in the container itself.

```yml
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
stringData:
  myKey: myPassword
```

Use the command `kubectl apply -f` and passing the above filename as argument to apply the secret to your Kubernetes cluster. Passing a secret to a container as an environment variable:

```yml
apiVersion: v1
kind: Pod
metadata:
  name: my-secret-pod
spec:
  containers:
  - name: myapp-container
    image: busybox
    command: ['sh', '-c', 'echo Hello, Kubernetes! & sleep 3600']
    env:
    - name: MY_PASSWORD
      valueFrom:
        secretKeyRef:
          name: my-secret
          key: myKey
```

### ServiceAccounts

**ServiceAccounts** allow containers running in pods to access the Kubernetes API. Some applications may need to interact with the cluster itself, and service accounts provide a way to let them do it securely, with properly limited permissions.

In order for this to work, you need an existing ServiceAccount in your cluster. For example, use the command `kubectl create serviceaccount my-serviceaccount` to create your ServiceAccount.

You can determine the ServiceAccount that a pod will use by specifying a `serviceAccountName` in the pod spec:

```yml
apiVersion: v1
kind: Pod
metadata:
  name: my-serviceaccount-pod
spec:
  serviceAccountName: my-serviceaccount
  containers:
  - name: myapp-container
    image: busybox
    command: ['sh', '-c', 'echo Hello, Kubernetes! & sleep 3600']
```

### Understanding Multi-Container Pods

**Multi-container pods** are simply pods with more than one container that all work together as a single unit. You can create multi-container pods by listing multiple containers in the pod spec:

```yml
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-pod
spec:
  containers:
  - name: nginx
    image: nginx:1.15.8
    ports:
    - containerPort: 80
  - name: busybox-sidecar
    image: busybox
    command: ['sh', '-c', 'while true; do sleep 30; done;']
```

There are three primary ways that containers can interact with one another in a pod:

* Shared network - all listening ports are accessible to other containers in the pod, even if they are not exposed outside the pod.
* Shared volume - containers can interact with each other by reading and modifying files in a shared storage volume that is mounted within both containers.
* Shared process namespace - with process namespace sharing enabled, containers in the same pod can interact with and signal one another's processes. This is enabled by setting `shareProcessNamespace: true` in the pod spec.

### Design Patterns for Multi-Container Pods

There are three patterns for multi-container pods:

* Sidecar pattern - uses a sidecar container that enhances or adds functionality to the main container in some way. For example, a sidecar that sync files from a Git repository to the file system in a web server container.
* Ambassador pattern - uses an ambassador container to accept network traffic and pass it on to the main container. For example, an ambassador that listens on a custom port, and forwards traffic to the main container on its hard-coded part.
* Adapter pattern - uses an adapter to change the output of the main container in some way. For example, an adapter that formats and decorates log output from the main container.

As an example of the ambassador pattern, we build a Kubernetes pod that runs a main `legacy-fruit-service` container (not shown) on port 8775, and uses the ambassador pattern to expose access to the service on port 80 (shown below).

The ambassador pattern consists of two Kubernetes objects: ConfigMap and Pod.

```yml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fruit-service-ambassador-config
data:
  haproxy.cfg: |-
    global
        daemon
        maxconn 256

    defaults
        mode http
        timeout connect 5000ms
        timeout client 50000ms
        timeout server 50000ms

    listen http-in
        bind *:80
        server server1 127.0.0.1:8775 maxconn 32
```

```yml
apiVersion: v1
kind: Pod
metadata:
  name: fruit-service
spec:
  containers:
  - name: legacy-fruit-service
    image: linuxacademycontent/legacy-fruit-service:1
  - name: haproxy-ambassador
    image: haproxy:1.7
    ports:
    - containerPort: 80
    volumeMounts:
    - name: config-volume
      mountPath: /usr/local/etc/haproxy
  volumes:
  - name: config-volume
    configMap:
      name: fruit-service-ambassador-config
```

This command gets the cluster's IP address for the pod:

```
kubectl get pod fruit-service -o=custom-columns=IP:.status.podIP --no-headers
```

### Liveness and Readiness Probes

*Probes* allow you to customize how Kubernetes determines the status of your containers.

*Liveness probe* indicates whether the container is running properly, and governs when the cluster will automatically stop or restart the container.

*Readiness probe* indicates whether the container is ready to service requests, and governs whether requests will be forwarded to the pod.

*Liveness and readiness probes* can determine container status by doing things like running a command or making an http request.

**Liveness probe**

Liveness probes can be created by including them in the container spec. This probe runs a command to test the container's livness.

```yml
apiVersion: v1
kind: Pod
metadata:
  name: my-liveness-pod
spec:
  containers:
  - name: myapp-container
    image: busybox
    command: ['sh', '-c', 'echo Hello, Kubernetes! && sleep 3600']
    livenessProbe:
      exec:
        command:
        - echo
        - testing
      initialDelaySeconds: 5
      periodSeconds: 5
```

**Readiness probe**

Readiness probes can also be created using the container spec. This probe uses an http request to test whether the container is ready to service requests.

```yml
apiVersion: v1
kind: Pod
metadata:
  name: my-readiness-pod
spec:
  containers:
  - name: myapp-container
    image: nginx
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 5
```

### Container Logging

A container's normal console output goes into the container log. You can access container logs using the `kubectl logs` command.

If a pod has more than one container, you must specify which container to get logs from using the `-c` flag:

```sh
kubectl logs <pod> -c <container>
```

### Installing Metrics Server

The Kubernetes Metrics Server provides an API which allows you to access data about your pods and nodes, such as CPU and memory usage.

You can install metrics server in a cluster like this:

```sh
cd ~/
git clone https://github.com/linuxacademy/metrics-server
kubectl apply -f ~/metrics-server/deploy/1.8+/
```

You can verify that the server is up and running like this:

```sh 
kubectl get --raw /apis/metrics.k8s.io/
```

Once the metrics server is running, it may take up to 5 minutes or so to begin collecting data.

### Monitoring Applications

With a working metrics server, you can use `kubectl top` to gather information about resource usage within the cluster.

Get resoure usage for all pods in the default namespace:

```sh
kubectl top pods
```

For a single pod, `kubectl top pod <pod_name>`. You can also get resource usage info for nodes:

```sh
kubectl top nodes
```

### Debugging

In order to debug applications in Kubernetes, you will need to combine several of the things you have already learned.

Debugging involves two essential steps: 1. Find the problem. 2. Fix the problem.

**Find the problem**

Use `kubectl get` to navigate through lists of objects. Be sure to use `--all-namespaces` to check all namespaces.

Get more info on a specific object using `kubectl describe`, and get container logs using `kubectl logs`.

**Fix the problem**

Edit an object's spec in the default editor:

```sh
kubectl edit <kind> <name>
```

Use this to get a clean yaml definition that you can then edit. This is useful if you need to delete, modify, and then re-create objects:

```sh
kubectl get <kind> <name> -o yaml --export
```

### Labels, Selectors, and Annotations

**Labels**

_Labels_ are key-value pairs attached to Kubernetes objects. They are used for identifying various attributes of objects which can in turn be used to select and group various subsets of those objects.

We can attach labels to objects by listing them in the `metadata.labels` section of an object spec:

```yml
apiVersion: v1
kind: Pod
metadata:
  name: my-prod-label-pod
  labels:
    app: my-app
    environment: production
spec:
  containers:
  - name: nginx
    image: nginx
```

You can view existing labels with:

```sh
kubectl get pods --show-label
```

**Selectors**

_Selectors_ are used for identifying and selecting a specific group of objects using their labels. One way to use selectors is to use them with `kubectl get` to retrieve a specific list of objects.

We can specify a selector using the `-l` flag. We can use equality-based selectors:

```sh
kubectl get pods -l app=my-app
```

Inequality:

```sh
kubectl get pods -l environment!=production
```

As well as set-based selectors:

```sh
kubectl get pods -l 'environment in (production,development)'
```

We can also chain multiple selectors together using a comma-delimited lists:

```sh
kubectl get pods -l app=my-app,environment=production
```

**Annotations**

_Annotations_ are similar to labels in that they can be used to store custom metadata about objects. However, unlike labels, annotations cannot be used to select or group objects in Kubernetes.

External tools can read, write, and interact with annotations. We can attach annotations to objects using the `metadata.annotations` section of the object descriptor.

```yml
apiVersion: v1
kind: Pod
metadata:
  name: my-annotation-pod
  annotations:
    owner: terry@linuxacademy.com
    git-commit: bdab0c6
spec:
  containers:
  - name: nginx
    image: nginx
```

Like labels, existing annotations can also be viewed using `kubectl describe pod`.

### Deployments

_Deployments_ provide a way to declaratively manage a dynamic set of replica pods. They provide powerful functionality such as scaling and rolling updates.

A deployment defines a _desired state_ for the replica pods. The cluster will constantly work to maintain that desired state, creating, removing, and modifying the replica pods accordingly.

A _deployment_ is a Kubernetes object that can be created using a descriptor:

```yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
  spec:
    containers:
    - name: nginx
      image: nginx:1.7.9
      ports:
      - containerPort: 80
```

Note the following:

* **spec.replicas** - The number of replica pods
* **spec.template** - A template pod descriptor which defines the pods which will be created
* **spec.selector** - The deployment will manage all pods whose labels match this selector

### Rolling Updates and Rollbacks

**Rolling Updates**

**Rolling updates** provide a way to update a deployment to a new container version by gradually updating replicas so that there is no downtime. Execute a rolling update with `kubectl set image`.

```sh
kubectl set image deployment/<deployment_name> <container_name>=<image_name> --record
```

The `--record` flag records information about the update so that it can be rolled back later.

**Rollbacks**

**Rollbacks** allow us to revert to a previous state. For example, if a rolling update breaks something, we can quickly recover by using a rollback.

Get a list of previous updates with `kubectl rollout history`:

```sh
kubectl rollout history deployment/<deployment_name>
```

The `--revision` flag will give more information on a specific revision number:

```sh
kubectl rollout history deployment/<deployment_name> --revision=<revision_number>
```

Undo the last revision with `kubectl rollout undo`:

```sh
kubectl rollout undo deployment/<deployment_name>
```

You can also rollback to a specific revision:

```sh
kubectl rollout undo deployment/<deployment_name> --to-revision=<revision_number>
```

### Jobs and CronJobs

**Jobs**

_Jobs_ can be used to reliably execute a workload until it completes. The job will create one or more pods.

When the job is finished, the container(s) will exit and the pod(s) will enter the _Completed_ state.

This job calculates the first 2000 digits of pi before exiting:

```yml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi
spec:
  template:
    spec:
      containers:
      - name: pi
        image: perl
        command: ["perl", "-Mbignum=bpi", "-wle", "print bpi(2000)"]
      restartPolicy: Never
  backoffLimit: 4
```

The `restartPolicy` descripter tells Kubernetes not to restart the pod upon completion of the command, while `backoffLimit` descriptor tells Kubernetes to try to restart the pod in case of a failure up to the specified limit.

You can use the command `kubectl logs <pod_name>` to view the output of the pod.

**CronJobs**

_CronJobs_ build upon the functionality of jobs by allowing you to execute jobs according to a schedule.

A CronJob's spec contains a _schedule_, where we can specify a cron expression to determine when and how often the job will be executed. It also contains a **jobTemplate**, where we can specify the job we want to run.

```yml
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: hello
spec:
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: hello
            image: busybox
            args:
            - /bin/sh
            - -c
            - date; echo Hello form the Kubernetes cluster
          restartPolicy: OnFailure
```

### Services

_Services_ create an abstraction layer which provides network access to a dynamic set of pods. Most services use a _selector_ to determine which pods will receive traffic through the service.

As pods included in the service are created and removed dynamically, clients can receive uninterrupted access by using the service.

Services are Kubernetes objects, which means that they can be created using **YAML** descriptors. Here is an example of a simple service:

```yml
apiVersion: v1
kind: Service
metadata:
  name: ClusterIP
spec:
  type: ClusterIP
  selector:
    app: nginx
  ports:
  - protocol: TCP
    port: 8080
    targetPort: 80
```

* **type** - Specifies the service type.
* **selector** - Service that will forward traffic to any pods with the label **app=nginx**.
* **port** - Specifies the port the service will listen on, and which one clients will use to access it.
* **targetPort** - Specifies the port that traffic will be forwarded to on the pods. If the port and targetPort are the same, it's safe to omit the targetPort.

To view all services, type `kubectl get services`, and to see which pods are associated with a service:

```sh
kubectl get endpoints <service_name>
```

There are four _service types_ in Kubernetes.

* **ClusterIP** - The service is exposed within the cluster using an internal IP address. The service is also accessible using the cluster DNS.

* **NodePort** - The service is exposed via a port which listens on each node in the cluster.

* **LoadBalancer** - This only works if your cluster is set up to work with a cloud provider. The service is exposed through a load balancer that is created on the cloud platform.

* **ExternalName** - This maps the service to an external address. It is used to allow resources within the cluster to access things outside the cluster through a service. This only sets up a DNS mapping, it does not proxy traffic.

#### Case Study

A company has just deployed two components of a web application to a Kubernetes cluster, using deployments with multiple replicas. We need a way to provide dynamic network access to these replicas so that there will be uninterrupted access to the components whenever replicas are created, removed, or replaced. 

One deployment is called **auth-deployment**, an authentication provider that needs to be accessible from outside the cluster. The other is called **data-deployment**, and it is a component designed to be accessed only by other pods within the cluster.

The team wants us to create two services to expose these two components. We'll create two services that meet the following criteria:

**auth-svc**
* The service name is auth-svc.
* The service exposes the pod replicas managed by auth-deployment, which has a label `app: auth` and `containerPort: 80`.
* The service listens on port 8080 and its targetPort matches the port exposed by the pods.
* The service type is NodePort.

**data-svc**
* The service name is data-svc.
* The service exposes the pod replicas managed by data-deployment, which has a label `app: data` and `containerPort: 80`.
* The service listens on port 8080 and its targetPort matches the port exposed by the pods.
* The service type is ClusterIP.

_Note: All work should be done in the default namespace._

Create a descriptor for an object **NodePort** and name the file `auth-svc.yml`. Ensure that the _selector_ and _targetPort_ matches the `auth-deployment`:

```yml
apiVersion: v1
kind: Service
metadata:
  name: auth-svc
spec:
  type: NodePort
  selector:
    app: auth
  ports:
  - protocol: TCP
    port: 8080
    targetPort: 80
```

Create a descriptor for an object **ClusterIP** and name the file `data-svc.yml`. Ensure that the _selector_ and _targetPort_ matches the `data-deployment`:

```yml
apiVersion: v1
kind: Service
metadata:
  name: data-svc
spec:
  type: ClusterIP
  selector:
    app: data
  ports:
  - protocol: TCP
    port: 8080
    targetPort: 80
```

Create both services in the cluster:

```sh
kubectl apply -f data-svc.yml -f auth-svc.yml
```

Check both services:

```sh
kubectl get svc
kubectl get ep auth-svc
kubectl get ep data-svc
```

### NetworkPolicies

In order to use NetworkPolicies in the cluster, we need to have a network plugin that supports them. We can accomplish this
alongside an existing flannel setup using canal:

```sh
wget -O canal.yaml https://docs.projectcalico.org/v3.5/getting-started/kubernetes/installation/hosted/canal/c
kubectl apply -f canal.yaml
```

By default, all pods in the cluster can communicate with any other pod, and reach out to any available IP.

**NetworkPolicies** allow you to limit what network traffic is allowed to and from pods in your cluster.

```yml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: my-network-policy
spec:
  podSelector:
    matchLabels:
      app: MyApp
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: MyApp
    ports:
    - protocol: TCP
      port: 6379
```

* **podSelector** - Determines which pods the NetworkPolicy applies to.
* **policyTypes** - Sets whether the policy governs incoming traffic (ingress), outgoing traffic (egress), or both.
* **ingress** - Rules for incoming traffic.
* **egress** - Rules for outgoing traffic.
* **rules** - Both ingress and egress rules are whitelist-based, meaning that any traffic that does not match at least one rule will be blocked.
  * **ports** - Specifies the protocols and ports that match the rule.
  * **from/to** selectors - Specifies the source(s) and destination(s) of network traffic that matches the rule.

From/to selectors are used to specify which traffic source(s) and destinations(s) are allowed by the rule. There are multiple types of selectors:

* **podSelector** - Matches traffic from/to pods which match the selector.
* **namespaceSelector** - Matches traffic from/to pods within namespaces which match the selector. Note that when podSelector and namespaceSelector are both present, the matching pods must also be within a matching namespace.
* **ipBlock** - Specifies a cidr range of IPs that will match the rule. This is mostly used for traffic from/to outside the clsuter. You can also specify exceptions to the range using _except_.

### Volumes

The internal storage of a container is _ephemeral_, meaning that it is designed to be highly temporary. _Volumes_ allow you to provide more permanent storage to a pod that exists beyond the life of a container.

```yml
apiVersion: v1
kind: Pod
metadata: 
  name: volume-pod
spec:
  containers:
  - image: busybox
    name: busybox
    command:
    - /bin/sh
    - -c
    - while true; do sleep 3600; done
    volumeMounts:
    - mountPath: /tmp/storage
      name: my-volume
  volumes:
  - name: my-volume
    emptyDir: {}
```

**EmptyDir** volumes create storage on a node when the pod is assigned to the node. The storage disappears when the pod leaves the node.

One of the use cases of EmptyDir is to create a shared storage between containers. Another container with the same **mountPath** can interact with the above container.

### State Persistence

Kubernetes is designed to manage _stateless_ containers. Pods and containers can be easily deleted and/or replaced. When a container is removed, data stored inside the container's internal disk is lost.

_State persistence_ refers to maintaining data outside and potentially beyond the life of a container. This usually means storing data in some kind of persistent data store that can be accessed by containers.

Kubernetes allows us to implement storage using **PersistentVolumes** and **PersistentVolumeClaims**.

* **PersistentVolume (PV)** - Represents a storage resource.
* **PersistentVolumeClaim (PVC)** - Abstraction layer between user (pod) and the PV.

PVCs will automatically bind themselves to a PV that has compatible **StorageClass** and **accessModes**.

**PersistentVolume**

Creating a PersistentVolume:

```yml
kind: PersistentVolume
apiVersion: v1
metadata:
  name: my-pv
spec:
  storageClassName: local-storage
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  hostPath:
    path: "mnt/data"
```

* **storageClassName** - Defines different custom categories of storage
* **capacity** - Storage amount for the PV
* **accessModes** - Determines what read/write modes can be used to mount the volume, e.g. **ReadWriteOnce** means only one pod can read/write at a time
* **hostPath** - Uses the node's local filesystem for storage

_Note: Multiple PVCs can bind to one PV, as long as total capacity does not exceed the PV's _capacity_.

**PersistentVolumeClaim**

Creating a PersistentVolumeClaim:

```yml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: my-pvc
spec:
  storageClassName: local-storage
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 512Mi
```

* **storageClassName** - Matches the storageClassName of a PV
* **accessModes** - Determines what read/write modes the claim needs
* **resources.requests.storage** - Defines how much storage the claim needs

Create a pod to mount a volume using a PVC:

```yml
kind: Pod
apiVersion: v1
metadata:
  name: my-pvc-pod
spec:
  containers:
  - name: busybox
    image: busybox
    command: ["/bin/sh", "-c", "while true; do sleep 3600; done"]
    volumeMounts:
    - mountPath: "/mnt/storage"
      name: my-storage
  volumes:
  - name: my-storage
    persistentVolumeClaim:
      claimName: my-pvc
```

### Preparing for the Exam

The exam is a practical exam, the best way to practice is doing all of the labs in the course until you can do them quickly.

You are allowed to use the Kubernetes documentation in the exam, hence familiarize yourself with the pages related to the concepts covered on the exam.

You have TWO (2) hours to complete the exam, but don't be afraid if you fail the exam the first time. When you sign up you will get a free retake exam.

### CKAD Exam Tips

* Set up `kubectl` bash autocomplete for use during the exam:

```sh
source < (kubectl completion bash)
echo "source < (kubectl completion bash)" >> ~/.bashrc
```

* Switch to root with `sudo -i` as soon as you start the exam.

* Pay attention to what cluster you are using. `kubectl config use-context` commands are given for each question to let you switch to the correct cluster.

* If you need to log in to a cluster node, the SSH command will be provided.

### What Next

* Certified Kubernetes Administrator (CKA)
* Docker Certified Associate (DCA)

### References

* [Communicate Between Containers in the Same Pod Using a Shared Volume](https://kubernetes.io/docs/tasks/access-application-cluster/communicate-containers-same-pod-shared-volume)
* [The Distributed System ToolKit: Patterns for Composite Containers](https://kubernetes.io/blog/2015/06/the-distributed-system-toolkit-patterns)
* [Certified Kubernetes Application Developer (CKAD) | Cloud Native Computing Foundation](https://www.cncf.io/certification/ckad)
