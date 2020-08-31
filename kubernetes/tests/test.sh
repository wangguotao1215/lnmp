#!/usr/bin/env bash

set -ex

echo "==> Set app"
mkdir -p ../app/laravel/public
cp lnmp/app/index.php ../app/laravel/public/

echo "==> Up nfs server"
./lnmp-k8s nfs
sleep 30
docker ps -a
./lnmp-k8s nfs logs
sudo mkdir -p /tmp2
# install nfs dep
sudo apt install -y nfs-common
sudo mount -t nfs4 -v ${SERVER_IP}:/lnmp/log /tmp2
sudo umount /tmp2

echo "==> set LNMP_NFS_SERVER_HOST .env"
# sed -i "s#192.168.199.100#${SERVER_IP}#g" .env

echo "==> Test LNMP with NFS"
cd lnmp
kubectl kustomize storage/pv/nfs | sed "s/192.168.199.100/${SERVER_IP}/g" | kubectl apply -f -
kubectl create ns lnmp
kubectl apply -k storage/pvc/nfs -n lnmp
kubectl apply -k redis/overlays/development -n lnmp
kubectl apply -k mysql/overlays/development -n lnmp
kubectl apply -k php/overlays/development -n lnmp
kubectl apply -k nginx/overlays/development -n lnmp
kubectl apply -k nginx/overlays/nodePort-80-443 -n lnmp
cd ..
echo "${SERVER_IP} laravel2.t.khs1994.com" | sudo tee -a /etc/hosts
ping -c 1 laravel2.t.khs1994.com || nslookup laravel2.t.khs1994.com
sleep 120
kubectl get -n lnmp all
curl -k https://laravel2.t.khs1994.com
kubectl delete ns lnmp
kubectl delete pv -l app=lnmp
./lnmp-k8s nfs down

echo "==> Test LNMP with hostpath"
cp -rf ../app ~/app-development
cd lnmp
kubectl kustomize storage/pv/linux | sed "s/__USERNAME__/$(whoami)/g" | kubectl apply -f -
kubectl create ns lnmp
kubectl apply -k storage/pvc/hostpath -n lnmp
kubectl apply -k redis/overlays/development -n lnmp
kubectl apply -k mysql/overlays/development -n lnmp
kubectl apply -k php/overlays/development -n lnmp
kubectl apply -k nginx/overlays/development -n lnmp
kubectl apply -k nginx/overlays/nodePort-80-443 -n lnmp
cd ..
sleep 50
kubectl get -n lnmp all
curl -k https://laravel2.t.khs1994.com

echo "==> Test runtimeclass runsc"
test -z "${LNMP_K8S_LOCAL_INSTALL_OPTIONS}" && (kubectl apply -f demo/runtimeClass/runtimeClass.containerd.yaml && kubectl apply -f demo/runtimeClass/runsc.yaml) || true
test "${LNMP_K8S_LOCAL_INSTALL_OPTIONS}" = "--crio" && (kubectl apply -f demo/runtimeClass/runtimeClass.yaml && kubectl apply -f demo/runtimeClass/runsc.yaml) || true
test "${LNMP_K8S_LOCAL_INSTALL_OPTIONS}" = "--docker" && docker run -it --rm --runtime=runsc alpine uname -a || true
test "${LNMP_K8S_LOCAL_INSTALL_OPTIONS}" = "--docker" && docker run -it --rm alpine uname -a || true
sleep 20
kubectl get all
kubectl get pod
POD_NAME=`kubectl get pod | awk '{print $1}' | tail -1` || true
kubectl exec ${POD_NAME} -- uname -a || true
kubectl describe pod/${POD_NAME} || true

echo "==> Test runtimeclass runc"
kubectl delete -f demo/runtimeClass/runsc.yaml || true
test -z "${LNMP_K8S_LOCAL_INSTALL_OPTIONS}" && (kubectl apply -f demo/runtimeClass/runc.yaml) || true
test "${LNMP_K8S_LOCAL_INSTALL_OPTIONS}" = "--crio" && (kubectl apply -f demo/runtimeClass/runc.yaml) || true
sleep 10
kubectl get all
kubectl get pod
POD_NAME=`kubectl get pod | awk '{print $1}' | tail -1` || true
kubectl exec ${POD_NAME} -- uname -a || true
kubectl describe pod/${POD_NAME} || true
