# Procfile Static Webserver Sample Application

## Building

```bash
pack build applications/procfile
```

## Running

```bash
docker run --tty --publish 8080:8080 applications/procfile
```

## Viewing

```bash
curl -s http://localhost:8080/hello-world.txt
```

The static-file-server-2.28.0-linux-amd64 and
static-file-server-2.28.0-linux-arm64 are from
https://github.com/static-web-server/static-web-server/releases/tag/v2.28.0
