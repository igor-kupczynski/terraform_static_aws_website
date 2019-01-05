A module which creates AWS infrastucture for serving a static website

It creates:

    1. S3 bucket configured to serve the stored resources as a webpage
    2. Cloudfront distribution which fronts the bucket
    3. Optionally a bucket which redirects www (or other subdomain) --> naked domain (and a cloud front if certificate arn is provided)

DNS configuration and publishing the website are left for the user and
are not a scope of this module (yet).

It is assumed that the aws credentials are provided via env variables.

User needs to create an SSL certificate in AWS certificate manager.

This module is used to provide the infra
for [my blog - kupczynski.info](https://kupczynski.info) and a couple
of other websites.

## Usage example

```
provider "aws" {
  region = "us-east-1"
}

module "geek_igor_hosting" {
  source = "github.com/igor-kupczynski/terraform_static_aws_website"

  domain              = "${var.domain}"     # for example "kupczynski.info"
  index_document      = "index.html"
  error_404_document  = "errors/404.html"
  redirect_subdomain  = "www"               # usually this is "www", skip if you don't need a subdomain redirect
  ssl_certificate_arn = "${var.cert}"       # can be generated in aws certificate manager, skip if you don't need a https connection
                                            #  managed by aws; skipping this won't generate a cloud front distribution at all
}
```
