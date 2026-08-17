# Feedpaper Docker and Helm packaging

This workspace contains:

- a Docker image definition for running `jonashonecker/feedpaper` as a one-off command
- a Helm chart that schedules `feedpaper` via a Kubernetes `CronJob`

## Docker image

Build the image locally:

```bash
docker build -t rarosalion/feedpaper-docker:local .
```

Run it once with a config file mounted in place:

```bash
mkdir -p ~/.config/feedpaper
cat > ~/.config/feedpaper/config <<'EOF'
email = you@example.com
password = your-feedbin-password
EOF
chmod 600 ~/.config/feedpaper/config

docker run --rm \
  -v "$HOME/.config/feedpaper/config:/root/.config/feedpaper/config:ro" \
  -v "$PWD/output:/output" \
  rarosalion/feedpaper-docker:local
```

## Helm chart

Install the chart with your Feedbin credentials and a schedule:

```bash
helm install feedpaper ./helm/feedpaper \
  --set feedpaper.config.email=you@example.com \
  --set feedpaper.config.password=your-feedbin-password \
  --set feedpaper.schedule='0 6 * * *'
```

A production-style configuration file is included at [helm/feedpaper/values.production.yaml](helm/feedpaper/values.production.yaml). It uses the current feedpaper image tag value from the chart (for example, `v0.1.1`) and can be used like this:

```bash
helm install feedpaper ./helm/feedpaper -f ./helm/feedpaper/values.production.yaml
```

The chart creates a Secret containing a `config` file, mounts it at `/root/.config/feedpaper/config`, and runs `feedpaper -o /output` on the configured CronJob schedule. The chart image repository is set to `rarosalion/feedpaper-docker`, and the Dockerfile builds from the vendored source checked into this repository at `./feedpaper`.

To suppress output persistence, set:

```bash
--set persistence.enabled=false
```

The generated EPUB files are written to the output directory selected by the Helm values (`/output` by default) and persist in the created PVC when persistence is enabled.

## Helm values reference

The chart is configured through [helm/feedpaper/values.yaml](helm/feedpaper/values.yaml). The complete set of supported values is:

```yaml
image:
  repository: rarosalion/feedpaper-docker   # Published image repository
  tag: "v0.1.1"                         # Pinned image tag
  pullPolicy: IfNotPresent

feedpaper:
  schedule: "0 6 * * *"                # Cron schedule for the job
  timezone: UTC                         # Cron timezone
  outputDir: /output                    # Directory passed to `feedpaper -o`
  keepUnread: false                     # Set to true to add `--keep-unread`
  extraArgs: []                         # Additional CLI args to pass through
  config:
    email: ""                          # Feedbin email address
    password: ""                       # Feedbin password
    excludes: []                        # Optional blog exclusions

mail:
  enabled: false                       # Send the generated EPUB by SMTP
  to: ""                              # Recipient address
  from: ""                            # Sender address
  subject: "feedpaper newspaper"      # Email subject
  smtpHost: ""                        # SMTP server hostname
  smtpPort: 587                        # SMTP port
  smtpStartTls: true                   # Use STARTTLS
  smtpUsername: ""                    # Optional SMTP username
  smtpPassword: ""                    # Optional SMTP password

cronjob:
  concurrencyPolicy: Forbid             # CronJob concurrency policy
  successfulJobsHistoryLimit: 1
  failedJobsHistoryLimit: 1
  suspend: false
  pod:
    annotations: {}
    labels: {}
    resources: {}
    nodeSelector: {}
    tolerations: []
    affinity: {}
    securityContext: {}

persistence:
  enabled: true                         # Mount a volume for the output directory
  type: pvc                             # pvc (dynamic provisioning) or s3 (static PV via the AWS Mountpoint S3 CSI driver)
  size: 1Gi
  accessMode: ReadWriteOnce
  storageClass: ""                      # Used when type=pvc
  s3:                                   # Used when type=s3
    bucketName: ""                      # Required: an existing bucket, the CSI driver does not create it
    endpointUrl: ""                     # Required: e.g. https://s3.example.com for an S3-compatible endpoint
    region: default
    fileMode: "666"
    dirMode: "777"
    extraMountOptions: []               # Additional mountpoint-s3 CLI flags, e.g. "prefix some/path/"

nameOverride: ""
fullnameOverride: ""
```

The wrapper script passes the configured values into the feedpaper process and only emails when `mail.enabled` is `true` and the feedpaper command exits successfully.

## Emailing the generated EPUB

The image includes a wrapper script that can email the newest EPUB after feedpaper completes. Set the mail settings in the values file:

```yaml
mail:
  enabled: true
  to: "reader@example.com"
  from: "feedpaper@example.com"
  subject: "Your daily feedpaper"
  smtpHost: "smtp.example.com"
  smtpPort: 587
  smtpStartTls: true
  smtpUsername: "smtp-user"
  smtpPassword: "smtp-password"
```

When `mail.enabled` is `true`, the script looks for the generated file named `feedpaper-YYYY-MM-DD.epub`, and then sends it to the configured address after the feedpaper run completes successfully. If you only want the file saved locally, leave `mail.enabled` as `false`.

## Feedpaper exit codes

The wrapper handles feedpaper's exit status according to the upstream CLI contract:

- `0`: success (including when there are no unread posts to build)
- `1`: runtime error, missing credentials, Feedbin failure, or failure to mark posts as read
- `2`: invalid command-line usage

If feedpaper exits with a non-zero code, the wrapper stops before sending email and returns the same exit status.
