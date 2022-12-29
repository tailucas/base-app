# base_app

Base application for various projects.

## Dependencies

* [1Password Connect](https://github.com/1Password/connect-sdk-python) which must vend the following properties and their associated values:
````
      APP_NAME: base_app
      DEVICE_NAME: base-app
      HC_PING_URL
      IPBASE_API_KEY
      OP_CONNECT_SERVER
      OP_CONNECT_TOKEN
      OP_VAULT
````
* [Healthchecks.io](https://healthchecks.io/)
* [pylib git submodule](https://github.com/tailucas/pylib)
* A [Docker repository](https://docs.docker.com/docker-hub/repos/) to store the built image.
