# Compose-hook

Simple application to update a service managed by compose using a webhook.
The trigger is secured with a shared secret.

## Usage

Install the gem:
```
gem install compose-hook
```

Install the systemd service on the target machine:
```
bin/install_webhook
```

Test your installation with a payload
```
compose-payload *service* *docker image* *url*
```

Made with :heart: at [openware](https://www.openware.com/)
