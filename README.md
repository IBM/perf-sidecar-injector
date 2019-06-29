# perf-sidecar-injector
Sample sidecar demonstrating automatic collection of container performance data using Linux perf tool in a Kubernetes cluster

# Introduction
This is a sidecar injector to allow injecting 'perf' container with PID sharing.<br>
The purpose of this injector is to inject 'perf' container in deployed PODs to capture perf statistics for
performance analysis

Acknowledgement: The code is based on Morven Cao's sample MutatingAdmissionWebhook as described in the following [medium article](https://medium.com/ibm-cloud/diving-into-kubernetes-mutatingadmissionwebhook-6ef3c5695f74). The code can be found [here](https://github.com/morvencao/kube-mutating-webhook-tutorial)

The first iteration of this work was by extending the [istio sidecar injector](https://github.com/bpradipt/istio)

# Note
'perf' container requires PID namespace sharing and privilege access.

Source for perf container is available from the following github [link](https://github.com/bpradipt/perf-container)

## Deploy
- Ensure you are using Kubernetes 1.10+ and the following settings enabled:
  - `PodShareProcessNamespace=true` feature-gate turned on
  - Ensure kube-apiserver has the `admission-control` flag set with `MutatingAdmissionWebhook` and `ValidatingAdmissionWebhook` admission controllers added
```
$kubectl api-versions | grep admissionregistration

admissionregistration.k8s.io/v1beta1
```

## Build

1. Setup dep

   The repo uses [dep](https://github.com/golang/dep) as the dependency management tool for its Go codebase. Install `dep` by the following command:
```
go get -u github.com/golang/dep/cmd/dep
```

2. Build and push docker image
   
```
make image
make release
```

## Deploy

1. Create a signed cert/key pair and store it in a Kubernetes `secret` that will be consumed by sidecar deployment

```
./deployment/webhook-create-signed-cert.sh \
    --service perf-sidecar-injector-webhook-svc \
    --secret perf-sidecar-injector-webhook-certs \
    --namespace default
```

2. Patch the `MutatingWebhookConfiguration` by setting `caBundle` with correct value from Kubernetes cluster
```
cat deployment/mutatingwebhook.yaml | \
    deployment/webhook-patch-ca-bundle.sh > \
    deployment/mutatingwebhook-ca-bundle.yaml
```

3. Deploy resources
```
kubectl create -f deployment/configmap.yaml
kubectl create -f deployment/deployment.yaml
kubectl create -f deployment/service.yaml
kubectl create -f deployment/mutatingwebhook-ca-bundle.yaml
```

## Verify

1. The sidecar inject webhook should be running
```
$ kubectl get pods
NAME                                                  READY     STATUS    RESTARTS   AGE
sidecar-injector-webhook-deployment-bbb689d69-882dd   1/1       Running   0          5m

$ kubectl get deployment
NAME                                  DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
sidecar-injector-webhook-deployment   1         1         1            1           5m
```

2. Label the default namespace with `sidecar-injector=enabled`
```
$ kubectl label namespace default sidecar-injector=enabled
$ kubectl get namespace -L sidecar-injector
NAME          STATUS    AGE       SIDECAR-INJECTOR
default       Active    18h       enabled
kube-public   Active    18h
kube-system   Active    18h
```

3. Deploy an app in Kubernetes cluster, take `sleep` app as an example
```
$ cat <<EOF | kubectl create -f -
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: sleep
spec:
  replicas: 1
  template:
    metadata:
      annotations:
        perf-sidecar-injector-webhook/inject: "yes"
      labels:
        app: sleep
    spec:
      containers:
      - name: sleep
        image: tutum/curl
        command: ["/bin/sleep","infinity"]
        imagePullPolicy: 
EOF
```

4. Verify sidecar container injected
```
$ kubectl get pods
NAME                     READY     STATUS        RESTARTS   AGE
sleep-5c55f85f5c-tn2cs   2/2       Running       0          1m
```

## Perf Considerations

1. Ensure the application binaries have symbol information otherwise `perf report -i <path_to_captured_perf_record>` will not be able to show the symbol names. You can use `file <path_to_binary>` to know if the symbols have been stripped from the binary or not

2. `perf report -i <path_to_captured_perf_record>` will require the application binary to resolve the symbol names. Let's say, you are using perf sidecar to capture data for `envoy` which is in the following path of the envoy container image - `/usr/local/bin/envoy`. 
You'll need to copy the envoy binary to the system where you are analyzing the `perf` data. In the `envoy` example, copy the binary from the respective container image to `/my_home/perf_data/usr/local/bin/envoy` and then run `perf report -i <path_to_captured_perf_record> --symfs /my_home/perf_data --kallsyms /proc/kallsyms`
