# Compose-hook


Simple application to update a service managed by compose using a webhook.
The trigger is secured with a shared secret.



### Installation

Install the gem:
```
  gem install compose-hook
```

Install the systemd service on the target machine:
```
  bin/install_webhook
```

Create a config file of the following format:
```yaml
- domain:  "www.example.com" # target domain
  root:    "/home/deploy/example" # the root location of docker-compose
  subpath: "compose" # [optional] directory containing target Compose files
- domain:  "its.awesome.com"
  root:    "/home/deploy/awesome"
  subpath: ""
```

Export the config file path as `CONFIG_PATH` before launching the server.

### Usage

Test your installation with a payload
```
  compose-payload *service* *docker image* *url*
```

Made with :heart: at [openware](https://www.openware.com/)
