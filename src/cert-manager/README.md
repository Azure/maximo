# Cert-Manager 1.6.1 with Lets Encrypt for Maximo Application Suite

## Introduction

In this folder you'll find a slightly modified cert-manager 1.6.1. It adds an arg for the DNS recursors for 8.8.8.8 and 1.1.1.1 to avoid using the internal OpenShift resolver. See the following issues that detail this: <https://github.com/cert-manager/website/pull/751>, <https://github.com/cert-manager/cert-manager/issues/1163>, <https://github.com/jetstack/cert-manager-olm/issues/17>.

Additionally you'll find a letsencrypt issuer that is set up to modify your public Azure DNS zone to provide the _acme challenge using cert-manager.

Prerequisites:

* OpenShift on Azure
* A service principal that you have the client ID and secret for (you can reuse the one from OpenShift)
* A public facing DNS zone on AzureDNS
* Maximo Application Suite set up

Steps to take:

<!-- TODO: See if we can reference the service principal in the openshift namespaces -->
1. Install cert-manager 1.6.1 with the modifications
1. Load your service principal into a secret in the cert-manager namespace
1. Set up the Letsencrypt Issuer to get valid certs
1. Instruct Maximo Application Suite to use the Issuer you just created

## How to install

If not available yet, create a namespace for cert-manager. It is recommended to use `cert-manager` for that. Do so with `oc project create cert-manager`. Switch to the namespace, `oc project cert-manager` to make sure everything is created in the right spot. Next, install cert-manager itself. If you have an existing cert-manager, this will overwrite the deploy.

```bash
oc apply -f cert-manager.yaml
```

Once that is done, create a client secret with your Azure client secret

```bash
oc create secret generic azuredns-config --from-literal=client-secret="B.y7Q~O-zBR8q~GC-ZoIsBVmGlxNzRgHQEiVK"
```

Now edit the letsencrypt.yaml and make sure it reflects your DNS zone, resource group, subscription, tenant, etc. Once done, apply it.

```bash
oc apply -f letsencrypt.yaml
```

If all went well, this means you can you now issue letsencrypt certifictes from cert-manager from the `letsencrypt-issuer`. If it isn't working all the way, check the certmanager logs to get an idea of what may be broken.

## Enabling the issuer in Maximo Application Suite

Grab an existing Maximo Application Suite install (or make a new one) and specify the issuer in the `spec` part of the YAML for the Suite CRD (`kind: Suite`).

```yml
spec:
  # Issuer below!
  certificateIssuer:
    duration: 2160h
    name: letsencrypt-issuer
    renewBefore: 360h
  domain: ....azuremaximo.com
  license:
    accept: true
```

## Thanks

Thank you Aldo Eisma@IBM for the pointers on how to get this set up.
